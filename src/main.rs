use std::{borrow::Cow, collections::HashMap};

use eyre::Result;
use log::{info, warn};
use sdl2::{
    event::{Event, WindowEvent},
    keyboard::Keycode,
    video::Window,
};
use wgpu::SurfaceError;

fn setup_logging() -> eyre::Result<()> {
    use fern::colors::{Color, ColoredLevelConfig};

    let colors_line = ColoredLevelConfig::new()
        .error(Color::Red)
        .warn(Color::Yellow)
        .info(Color::White)
        .debug(Color::White)
        .trace(Color::BrightBlack);

    let colors_level = colors_line.info(Color::Green);

    fern::Dispatch::new()
        .format(move |out, message, record| {
            out.finish(format_args!(
                "{color_line}[{date} {level} {target} {color_line}] {message}\x1B[0m",
                color_line = format_args!(
                    "\x1B[{}m",
                    colors_line.get_color(&record.level()).to_fg_str()
                ),
                date = humantime::format_rfc3339_seconds(std::time::SystemTime::now()),
                target = record.target(),
                level = colors_level.color(record.level()),
                message = message,
            ));
        })
        .level(log::LevelFilter::Debug)
        .level_for("naga", log::LevelFilter::Warn)
        .chain(std::io::stdout())
        .chain(fern::log_file("output.log")?)
        .apply()?;

    Ok(())
}

async fn test_win() -> Result<()> {
    let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor::default());

    let context = sdl2::init().expect("SDL2 Failed to initialize");

    let video_subsystem = context.video().unwrap();

    let window: Window = {
        let mut window = video_subsystem.window("epic", 640, 480);

        window.position_centered();
        window.fullscreen_desktop();

        #[cfg(target_os = "macos")]
        {
            window.metal_view();
        }

        window.build()?
    };

    let (width, height) = window.size();

    let surface = unsafe {
        let target = { wgpu::SurfaceTargetUnsafe::from_window(&window)? };
        instance.create_surface_unsafe(target)?
    };

    let adapter = instance
        .request_adapter(&wgpu::RequestAdapterOptions::default())
        .await?;

    let (device, queue) = adapter
        .request_device(&wgpu::DeviceDescriptor {
            required_limits: wgpu::Limits::downlevel_webgl2_defaults(),
            ..Default::default()
        })
        .await?;

    let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: Some("shader"),
        source: wgpu::ShaderSource::Wgsl(Cow::Borrowed(include_str!("shader.wgsl"))),
    });

    let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
        entries: &[],
        label: Some("bind_group_layout"),
    });
    let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
        layout: &bind_group_layout,
        entries: &[],
        label: Some("bind_group"),
    });
    let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
        bind_group_layouts: &[&bind_group_layout],
        label: None,
        push_constant_ranges: &[],
    });

    let compilation_options = wgpu::PipelineCompilationOptions {
        constants: &[],
        zero_initialize_workgroup_memory: true,
    };

    let render_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
        layout: Some(&pipeline_layout),
        vertex: wgpu::VertexState {
            buffers: &[],
            module: &shader,
            entry_point: Some("vs_main"),
            compilation_options: compilation_options.clone(),
        },
        fragment: Some(wgpu::FragmentState {
            targets: &[Some(wgpu::ColorTargetState {
                format: wgpu::TextureFormat::Bgra8UnormSrgb,
                blend: None,
                write_mask: wgpu::ColorWrites::ALL,
            })],
            module: &shader,
            entry_point: Some("fs_main"),
            compilation_options: compilation_options.clone(),
        }),
        primitive: wgpu::PrimitiveState {
            topology: wgpu::PrimitiveTopology::TriangleList,
            strip_index_format: None,
            front_face: wgpu::FrontFace::Ccw,
            cull_mode: Some(wgpu::Face::Front),
            unclipped_depth: false,
            polygon_mode: wgpu::PolygonMode::Fill,
            conservative: false,
        },
        depth_stencil: None,
        label: None,
        multisample: wgpu::MultisampleState {
            count: 1,
            mask: !0,
            alpha_to_coverage_enabled: false,
        },
        multiview: None,
        cache: None,
    });

    let surface_caps = surface.get_capabilities(&adapter);

    let surface_format = surface_caps
        .formats
        .iter()
        .copied()
        .find(|f| f.is_srgb())
        .unwrap_or(surface_caps.formats[0]);

    let mut config = wgpu::SurfaceConfiguration {
        usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
        format: surface_format,
        width,
        height,
        present_mode: wgpu::PresentMode::Fifo,
        alpha_mode: wgpu::CompositeAlphaMode::Auto,
        view_formats: Vec::default(),
        desired_maximum_frame_latency: 2,
    };
    surface.configure(&device, &config);

    let mut event_pump = context
        .event_pump()
        .expect("Failed to start event loop for SDL");

    'running: loop {
        for event in event_pump.poll_iter() {
            match event {
                Event::Window {
                    window_id,
                    win_event: WindowEvent::SizeChanged(width, height),
                    ..
                } if window_id == window.id() => {
                    config.width = width as u32;
                    config.height = height as u32;
                    surface.configure(&device, &config);
                }
                Event::Quit { .. }
                | Event::KeyDown {
                    keycode: Some(Keycode::Escape),
                    ..
                } => {
                    break 'running;
                }
                e => {}
            }
        }

        let frame = match surface.get_current_texture() {
            Ok(frame) => frame,
            Err(err) => {
                warn!("Failed to get current surface texture! Reason: {:?}", err);
                continue 'running;
            }
        };

        let output = frame
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("command_encoder"),
        });

        {
            let mut rpass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &output,
                    resolve_target: None,
                    depth_slice: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::GREEN),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                label: None,
                timestamp_writes: None,
                occlusion_query_set: None,
            });
            rpass.set_pipeline(&render_pipeline);
            rpass.set_bind_group(0, &bind_group, &[]);
            rpass.draw(0..3, 0..1);
        }
        queue.submit([encoder.finish()]);
        frame.present();
    }

    Ok(())
}

fn main() -> Result<()> {
    color_eyre::install()?;
    setup_logging()?;

    info!("epic gaming");

    pollster::block_on(test_win())?;

    Ok(())
}

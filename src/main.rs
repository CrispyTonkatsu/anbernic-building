use eyre::Result;
use log::info;
use wgpu::{InstanceDescriptor, Limits};

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
    let instance = wgpu::Instance::new(&InstanceDescriptor::default());

    let adapter = instance
        .request_adapter(&wgpu::RequestAdapterOptions::default())
        .await?;

    info!("Found adapter {}", adapter.get_info().name);

    info!("Adapter Limits: {:#?}\n", adapter.limits());

    let (device, queue) = adapter
        .request_device(&wgpu::DeviceDescriptor {
            required_limits: Limits::downlevel_webgl2_defaults(),
            ..Default::default()
        })
        .await?;

    println!("Retrieved device and queue");

    Ok(())
}

fn main() -> Result<()> {
    color_eyre::install()?;
    setup_logging()?;

    info!("epic gaming");

    pollster::block_on(test_win())?;

    Ok(())
}

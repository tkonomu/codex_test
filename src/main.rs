use std::env;
use std::fmt;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Copy, Clone, Debug)]
enum Preset {
    Mild,
    Heavy,
    Brutal,
}

impl Preset {
    fn parse(raw: &str) -> Result<Self, String> {
        match raw {
            "mild" => Ok(Self::Mild),
            "heavy" => Ok(Self::Heavy),
            "brutal" => Ok(Self::Brutal),
            _ => Err(format!(
                "invalid --preset '{raw}'. expected: mild | heavy | brutal"
            )),
        }
    }
}

#[derive(Debug)]
struct Cli {
    input: PathBuf,
    output: PathBuf,
    preset: Preset,
    noise: Option<u8>,
    bloom: Option<f32>,
    chroma_shift: Option<u8>,
    crf: u8,
    speed: String,
    dry_run: bool,
}

#[derive(Debug)]
struct EffectParams {
    noise: u8,
    bloom: f32,
    chroma_shift: u8,
    saturation: f32,
    contrast: f32,
    brightness: f32,
    gamma: f32,
    red_lift: f32,
    blue_lift: f32,
    blur_sigma: f32,
}

impl EffectParams {
    fn from_cli(cli: &Cli) -> Result<Self, String> {
        let mut p = match cli.preset {
            Preset::Mild => Self {
                noise: 16,
                bloom: 0.20,
                chroma_shift: 1,
                saturation: 1.15,
                contrast: 1.05,
                brightness: 0.03,
                gamma: 0.97,
                red_lift: 1.05,
                blue_lift: 1.02,
                blur_sigma: 0.9,
            },
            Preset::Heavy => Self {
                noise: 30,
                bloom: 0.33,
                chroma_shift: 2,
                saturation: 1.28,
                contrast: 1.12,
                brightness: 0.05,
                gamma: 0.94,
                red_lift: 1.10,
                blue_lift: 1.04,
                blur_sigma: 1.3,
            },
            Preset::Brutal => Self {
                noise: 45,
                bloom: 0.45,
                chroma_shift: 3,
                saturation: 1.45,
                contrast: 1.18,
                brightness: 0.07,
                gamma: 0.90,
                red_lift: 1.15,
                blue_lift: 1.08,
                blur_sigma: 1.8,
            },
        };

        if let Some(noise) = cli.noise {
            if noise > 100 {
                return Err("--noise must be between 0 and 100".to_string());
            }
            p.noise = noise;
        }
        if let Some(bloom) = cli.bloom {
            if !(0.0..=1.0).contains(&bloom) {
                return Err("--bloom must be between 0.0 and 1.0".to_string());
            }
            p.bloom = bloom;
        }
        if let Some(chroma_shift) = cli.chroma_shift {
            if chroma_shift > 10 {
                return Err("--chroma-shift must be between 0 and 10".to_string());
            }
            p.chroma_shift = chroma_shift;
        }

        Ok(p)
    }

    fn filtergraph(&self) -> String {
        format!(
            concat!(
                "format=yuv420p,",
                "eq=saturation={sat}:contrast={con}:brightness={bri}:gamma={gam},",
                "colorchannelmixer=rr={rr}:bb={bb},",
                "rgbashift=rh={shift}:bh=-{shift},",
                "split=2[base][b],",
                "[b]gblur=sigma={sigma}[blur],",
                "[base][blur]blend=all_mode=screen:all_opacity={bloom}[glow],",
                "[glow]noise=alls={noise}:allf=t+u"
            ),
            sat = self.saturation,
            con = self.contrast,
            bri = self.brightness,
            gam = self.gamma,
            rr = self.red_lift,
            bb = self.blue_lift,
            shift = self.chroma_shift,
            sigma = self.blur_sigma,
            bloom = self.bloom,
            noise = self.noise,
        )
    }
}

#[derive(Debug)]
struct CliError(String);

impl fmt::Display for CliError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

fn parse_value<T: std::str::FromStr>(value: Option<String>, flag: &str) -> Result<T, CliError> {
    let raw = value.ok_or_else(|| CliError(format!("missing value for {flag}")))?;
    raw.parse::<T>()
        .map_err(|_| CliError(format!("invalid value for {flag}: {raw}")))
}

fn parse_args() -> Result<Cli, CliError> {
    let mut args = env::args().skip(1);

    let mut input: Option<PathBuf> = None;
    let mut output: Option<PathBuf> = None;
    let mut preset = Preset::Heavy;
    let mut noise = None;
    let mut bloom = None;
    let mut chroma_shift = None;
    let mut crf: u8 = 18;
    let mut speed = "medium".to_string();
    let mut dry_run = false;

    while let Some(arg) = args.next() {
        match arg.as_str() {
            "-h" | "--help" => {
                print_help();
                std::process::exit(0);
            }
            "-i" | "--input" => {
                input = Some(PathBuf::from(parse_value::<String>(
                    args.next(),
                    "--input",
                )?))
            }
            "-o" | "--output" => {
                output = Some(PathBuf::from(parse_value::<String>(
                    args.next(),
                    "--output",
                )?))
            }
            "-p" | "--preset" => {
                let raw: String = parse_value(args.next(), "--preset")?;
                preset = Preset::parse(&raw).map_err(CliError)?;
            }
            "--noise" => noise = Some(parse_value(args.next(), "--noise")?),
            "--bloom" => bloom = Some(parse_value(args.next(), "--bloom")?),
            "--chroma-shift" => chroma_shift = Some(parse_value(args.next(), "--chroma-shift")?),
            "--crf" => crf = parse_value(args.next(), "--crf")?,
            "--speed" => speed = parse_value(args.next(), "--speed")?,
            "--dry-run" => dry_run = true,
            _ => return Err(CliError(format!("unknown argument: {arg}"))),
        }
    }

    let input = input.ok_or_else(|| CliError("--input is required".to_string()))?;
    let output = output.ok_or_else(|| CliError("--output is required".to_string()))?;

    Ok(Cli {
        input,
        output,
        preset,
        noise,
        bloom,
        chroma_shift,
        crf,
        speed,
        dry_run,
    })
}

fn print_help() {
    println!(
        "analog-dirty-video\n\n\
Usage:\n  analog-dirty-video --input in.mp4 --output out.mp4 [options]\n\n\
Options:\n  -i, --input <PATH>         Input video path (required)\n  -o, --output <PATH>        Output video path (required)\n  -p, --preset <NAME>        mild | heavy | brutal (default: heavy)\n      --noise <0..100>       Override grain amount\n      --bloom <0.0..1.0>     Override bloom blend opacity\n      --chroma-shift <0..10> Override RGB shift in pixels\n      --crf <0..51>          x264 quality (default: 18)\n      --speed <PRESET>       x264 speed preset (default: medium)\n      --dry-run              Print ffmpeg command only\n  -h, --help                 Show this help\n"
    );
}

fn ensure_input_exists(path: &Path) -> Result<(), String> {
    if !path.exists() {
        return Err(format!("input file does not exist: {}", path.display()));
    }
    Ok(())
}

fn ffmpeg_exists() -> bool {
    Command::new("ffmpeg")
        .arg("-version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn run() -> Result<(), String> {
    let cli = parse_args().map_err(|e| e.to_string())?;
    ensure_input_exists(&cli.input)?;

    if !ffmpeg_exists() {
        return Err("ffmpeg was not found in PATH. Install ffmpeg first, then re-run.".to_string());
    }

    let params = EffectParams::from_cli(&cli)?;
    let filtergraph = params.filtergraph();

    let mut cmd = Command::new("ffmpeg");
    cmd.arg("-y")
        .arg("-i")
        .arg(&cli.input)
        .arg("-vf")
        .arg(&filtergraph)
        .arg("-c:v")
        .arg("libx264")
        .arg("-crf")
        .arg(cli.crf.to_string())
        .arg("-preset")
        .arg(&cli.speed)
        .arg("-c:a")
        .arg("copy")
        .arg(&cli.output);

    if cli.dry_run {
        eprintln!("Dry run mode. ffmpeg command:\n{cmd:?}");
        return Ok(());
    }

    let status = cmd
        .status()
        .map_err(|e| format!("failed to spawn ffmpeg: {e}"))?;
    if !status.success() {
        return Err(format!("ffmpeg failed with exit status: {status}"));
    }

    eprintln!("Done: {}", cli.output.display());
    Ok(())
}

fn main() {
    if let Err(e) = run() {
        eprintln!("Error: {e}");
        std::process::exit(1);
    }
}

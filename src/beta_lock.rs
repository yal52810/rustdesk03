use hbb_common::config::Config;

const BETA_PASSWORD: &str = "29802988";
const BETA_DURATION_SECS: i64 = 86400; // 24 hours

fn timestamp_path() -> std::path::PathBuf {
    Config::path("beta_ts")
}

fn verified_path() -> std::path::PathBuf {
    Config::path("beta_vf")
}

pub fn init_first_run() {
}

pub fn get_remaining_seconds() -> i64 {
    let path = timestamp_path();
    if let Ok(data) = std::fs::read_to_string(&path) {
        if let Ok(start) = data.trim().parse::<i64>() {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs() as i64;
            let remaining = BETA_DURATION_SECS - (now - start);
            return if remaining > 0 { remaining } else { 0 };
        }
    }
    BETA_DURATION_SECS
}

pub fn is_expired() -> bool {
    get_remaining_seconds() <= 0
}

pub fn verify_password(pwd: &str) -> bool {
    if pwd != BETA_PASSWORD || is_expired() {
        return false;
    }
    let timestamp = timestamp_path();
    if !timestamp.exists() {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as i64;
        let _ = std::fs::write(&timestamp, now.to_string());
    }
    let _ = std::fs::write(verified_path(), "1");
    true
}

pub fn is_verified() -> bool {
    verified_path().exists() && timestamp_path().exists() && !is_expired()
}

pub fn needs_password() -> bool {
    #[cfg(feature = "beta-locked")]
    {
        true
    }
    #[cfg(not(feature = "beta-locked"))]
    {
        false
    }
}

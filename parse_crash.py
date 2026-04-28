import io
def parse():
    with io.open("crash_run.log", "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
        
    out = io.open("crash_result.txt", "w", encoding="utf-8")
    out.write("Filtered log for app crash:\n")
    for line in lines:
        lower = line.lower()
        if "harmony_player" in lower or "androidruntime" in lower or "fatal" in lower or "exception" in lower or "flutter" in lower:
            out.write(line)
parse()

import os

directory = "Sources/Nexor"
for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith(".swift") and file != "NexorApp.swift":
            path = os.path.join(root, file)
            with open(path, "r") as f:
                content = f.read()
            if not content.startswith("#if os(macOS)"):
                with open(path, "w") as f:
                    f.write("#if os(macOS)\n" + content + "\n#endif\n")

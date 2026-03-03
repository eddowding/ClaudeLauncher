import SwiftUI
import AppKit

struct ContentView: View {
    weak var panel: FloatingPanel?

    @State private var prompt: String = ""
    @State private var response: String = ""
    @State private var isLoading: Bool = false
    @State private var currentProcess: Process?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Response area (above the input, grows upward)
            if !response.isEmpty || isLoading {
                ScrollViewReader { proxy in
                    ScrollView {
                        if response.isEmpty && isLoading {
                            Text("Thinking...")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .id("bottom")
                        } else {
                            Text(markdownAttributedString(from: response))
                                .font(.system(size: 14))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .id("bottom")
                        }
                    }
                    .onChange(of: response) { _, _ in
                        proxy.scrollTo("bottom", anchor: .bottom)
                        // Nudge the panel to resize
                        panel?.resizeToFitContent()
                    }
                }
                .frame(minHeight: 60, maxHeight: 360)

                HStack(spacing: 12) {
                    if !response.isEmpty {
                        Button(action: copyResponse) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !isLoading {
                        Button(action: clearAndRefocus) {
                            Label("New", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Divider()
                    .padding(.horizontal, 12)
            }

            // Input row
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 14))

                TextField("Ask Claude anything...", text: $prompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($inputFocused)
                    .onSubmit { sendPrompt() }
                    .disabled(isLoading)

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else if !prompt.isEmpty {
                    Button(action: sendPrompt) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }

                Text("⌥Space")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quaternary.opacity(0.3))
                    .cornerRadius(3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 680)
        .onAppear {
            inputFocused = true
        }
        .onChange(of: isLoading) { _, loading in
            // Resize when loading starts/stops (content appears/changes)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                panel?.resizeToFitContent()
            }
        }
        .onExitCommand { panel?.close() }
    }

    private func sendPrompt() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        isLoading = true
        response = ""
        prompt = ""

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        // Working directory: CLAUDE_LAUNCHER_DIR env var, or ~/.claude-launcher-dir file, or $HOME
        let workDir = Self.resolveWorkingDirectory()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "unset CLAUDECODE; cd \(shellEscape(workDir)); exec claude -p \(shellEscape(text)) --output-format text --verbose"]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        var env: [String: String] = [:]
        env["HOME"] = NSHomeDirectory()
        env["USER"] = NSUserName()
        env["TERM"] = "dumb"
        env["SHELL"] = "/bin/zsh"
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            env["PATH"] = path
        }
        process.environment = env

        currentProcess = process

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let chunk = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    response += chunk
                }
            }
        }

        var stderrOutput = ""
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let chunk = String(data: data, encoding: .utf8) {
                stderrOutput += chunk
            }
        }

        process.terminationHandler = { proc in
            DispatchQueue.main.async {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let log = "exit: \(proc.terminationStatus)\nstdout bytes: \(response.count)\nstdout: \(response)\nstderr: \(stderrOutput)"
                try? log.write(toFile: "/tmp/claude-launcher.log", atomically: true, encoding: .utf8)

                if response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !stderrOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        response = "Error (exit \(proc.terminationStatus)):\n\(stderrOutput)"
                    } else if proc.terminationStatus != 0 {
                        response = "Process exited with code \(proc.terminationStatus) (no output)"
                    }
                }
                isLoading = false
                currentProcess = nil
            }
        }

        do {
            try process.run()
        } catch {
            response = "Failed to launch: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func copyResponse() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(response, forType: .string)
    }

    private func clearAndRefocus() {
        currentProcess?.terminate()
        prompt = ""
        response = ""
        isLoading = false
        inputFocused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            panel?.resizeToFitContent()
        }
    }

    /// Resolve working directory: env var > dotfile > $HOME
    private static func resolveWorkingDirectory() -> String {
        // 1. CLAUDE_LAUNCHER_DIR env var
        if let dir = ProcessInfo.processInfo.environment["CLAUDE_LAUNCHER_DIR"],
           !dir.isEmpty {
            return dir
        }
        // 2. ~/.claude-launcher-dir file (single line, path)
        let dotfile = NSHomeDirectory() + "/.claude-launcher-dir"
        if let contents = try? String(contentsOfFile: dotfile, encoding: .utf8) {
            let path = contents.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty { return path }
        }
        // 3. Default to home
        return NSHomeDirectory()
    }

    private func markdownAttributedString(from text: String) -> AttributedString {
        // Try to parse as markdown, fall back to plain text
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(text)
    }
}

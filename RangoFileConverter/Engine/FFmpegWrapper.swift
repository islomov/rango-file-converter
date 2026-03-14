import Foundation
import FFmpegSupport

/// Low-level wrapper around FFmpeg's CLI-style execution.
/// Actor-isolated to serialize calls — FFmpeg uses global state and is not thread-safe.
actor FFmpegWrapper {

    static let shared = FFmpegWrapper()

    enum FFmpegError: Error, LocalizedError {
        case executionFailed(code: Int, command: String, stderr: String)
        case inputFileNotFound(String)
        case outputDirectoryNotWritable(String)

        var errorDescription: String? {
            switch self {
            case .executionFailed(let code, let command, let stderr):
                var msg = "FFmpeg exited with code \(code)\nCommand: \(command)"
                if !stderr.isEmpty {
                    msg += "\nOutput: \(stderr.suffix(500))"
                }
                return msg
            case .inputFileNotFound(let path):
                return "Input file not found: \(path)"
            case .outputDirectoryNotWritable(let path):
                return "Cannot write to directory: \(path)"
            }
        }
    }

    /// List available encoders. Useful for debugging which formats are supported.
    func listEncoders() {
        _ = ffmpeg(["ffmpeg", "-encoders"])
    }

    /// List available muxers. Useful for debugging which output formats are supported.
    func listMuxers() {
        _ = ffmpeg(["ffmpeg", "-muxers"])
    }

    /// Execute an FFmpeg command with CLI-style arguments.
    /// The first element should be "ffmpeg".
    @discardableResult
    func execute(_ arguments: [String]) throws -> Int {
        let commandStr = arguments.joined(separator: " ")
        print("[FFmpeg] Executing: \(commandStr)")

        // Redirect stderr to a temp file to capture FFmpeg's error output
        let stderrFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("ffmpeg_stderr_\(UUID().uuidString.prefix(8)).txt")
        let stderrPath = stderrFile.path

        // Save original stderr, redirect to file
        let origStderr = dup(STDERR_FILENO)
        if let fp = fopen(stderrPath, "w") {
            let fd = fileno(fp)
            dup2(fd, STDERR_FILENO)
            fclose(fp)
        }

        let code = ffmpeg(arguments)

        // Restore original stderr
        dup2(origStderr, STDERR_FILENO)
        close(origStderr)

        // Read captured stderr
        let stderrOutput = (try? String(contentsOfFile: stderrPath, encoding: .utf8)) ?? ""
        try? FileManager.default.removeItem(atPath: stderrPath)

        print("[FFmpeg] Exit code: \(code)")
        if !stderrOutput.isEmpty {
            print("[FFmpeg] stderr: \(stderrOutput.suffix(1000))")
        }

        guard code == 0 else {
            throw FFmpegError.executionFailed(code: code, command: commandStr, stderr: stderrOutput)
        }
        return code
    }

    /// Convert a file from one format to another.
    /// - Parameters:
    ///   - inputURL: Source file URL (must be a local file).
    ///   - outputURL: Destination file URL.
    ///   - extraArgs: Additional FFmpeg arguments inserted between input and output
    ///                (e.g., ["-vf", "scale=1920:1080"]).
    func convert(
        input inputURL: URL,
        output outputURL: URL,
        extraArgs: [String] = []
    ) throws {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw FFmpegError.inputFileNotFound(inputURL.path)
        }

        let outputDir = outputURL.deletingLastPathComponent()
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: outputDir.path, isDirectory: &isDir), isDir.boolValue else {
            throw FFmpegError.outputDirectoryNotWritable(outputDir.path)
        }

        var args = ["ffmpeg", "-y", "-i", inputURL.path]
        args.append(contentsOf: extraArgs)
        args.append(outputURL.path)

        try execute(args)
    }
}

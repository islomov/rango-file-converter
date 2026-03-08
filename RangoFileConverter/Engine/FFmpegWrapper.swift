import Foundation
import FFmpegSupport

/// Low-level wrapper around FFmpeg's CLI-style execution.
/// Actor-isolated to serialize calls — FFmpeg uses global state and is not thread-safe.
actor FFmpegWrapper {

    static let shared = FFmpegWrapper()

    enum FFmpegError: Error, LocalizedError {
        case executionFailed(code: Int)
        case inputFileNotFound(String)
        case outputDirectoryNotWritable(String)

        var errorDescription: String? {
            switch self {
            case .executionFailed(let code):
                return "FFmpeg exited with code \(code)"
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

    /// Execute an FFmpeg command with CLI-style arguments.
    /// The first element should be "ffmpeg".
    @discardableResult
    func execute(_ arguments: [String]) throws -> Int {
        print("[FFmpeg] Executing: \(arguments.joined(separator: " "))")
        let code = ffmpeg(arguments)
        print("[FFmpeg] Exit code: \(code)")
        guard code == 0 else {
            throw FFmpegError.executionFailed(code: code)
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

module utilities;

import std.stdio;
import core.time;      // For MonoTime and Duration
import std.datetime;   // For date and time utilities (if needed)
import std.conv;       // For to! conversion

/// A simple performance monitor that measures frame time and FPS.
/// Note: CPU and GPU utilization are not implemented here.
class PerformanceMonitor {
    Duration frameStartTime;
    Duration lastFrameDuration;
    size_t frameCount;
    Duration totalTime;

    this() {
        frameStartTime = MonoTime.currTime;
        lastFrameDuration = Duration.zero;
        frameCount = 0;
        totalTime = Duration.zero;
    }

    /// Call at the beginning of each frame.
    void beginFrame() {
        frameStartTime = MonoTime.currTime;
    }

    /// Call at the end of each frame.
    void endFrame() {
        auto now = MonoTime.currTime;
        lastFrameDuration = now - frameStartTime;
        totalTime += lastFrameDuration;
        frameCount++;
    }

    /// Returns the FPS for the last frame.
    double getFPS() {
        double ms = lastFrameDuration.total!"msecs";
        return ms > 0 ? 1000.0 / ms : 0.0;
    }

    /// Returns the average FPS since the monitor was started.
    double getAverageFPS() {
        double ms = totalTime.total!"msecs";
        return ms > 0 ? (frameCount * 1000.0) / ms : 0.0;
    }

    /// Returns the last frame time in milliseconds.
    double getFrameTimeMS() {
        return lastFrameDuration.total!"msecs";
    }

    /// Stub for CPU utilization.
    double getCPUUtilization() {
        // For actual CPU utilization, you'd need to query OS-specific APIs.
        return 0.0;
    }

    /// Stub for GPU utilization.
    double getGPUUtilization() {
        // For actual GPU utilization, you might use vendor-specific APIs like NVAPI (for NVIDIA).
        return 0.0;
    }

    /// Print the collected metrics to the console.
    void printMetrics() {
        writeln("Frame Time (ms): ", getFrameTimeMS());
        writeln("FPS (last frame): ", getFPS());
        writeln("Average FPS: ", getAverageFPS());
        writeln("CPU Utilization (%): ", getCPUUtilization());
        writeln("GPU Utilization (%): ", getGPUUtilization());
    }
}

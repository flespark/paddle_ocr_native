# Benchmarks

Benchmark numbers are hardware-, image-, and configuration-dependent. The
project records raw detection and recognition time separately and does not
claim a universal accuracy or latency figure.

## Accepted device baseline

| Platform | Device | Configuration | Result |
| --- | --- | --- | --- |
| Android | V2419A arm64, API 35 | `handwrittenRows` | 16 raw regions on the private 16-row regression image |
| iOS | iPhone 13 mini, iOS 26.5.2 | `handwrittenRows` | 16 raw regions, 15 clustered application rows on the same image |

The iOS run measured approximately 670 ms detection and 3900 ms recognition.
These values are historical regression baselines from the host application,
not package performance guarantees.

Every model, threshold, preprocessing, or postprocessing change must record:

- package commit and model hashes;
- device and OS version;
- source image dimensions and license/privacy status;
- cold initialization, detection, and recognition time;
- raw region count and expected-text comparison;
- the same comparison on Android and iOS physical devices.

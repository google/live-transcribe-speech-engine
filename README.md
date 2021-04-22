# The Live Transcribe Speech Engine

(This is not an official Google product!)

[Live Transcribe](https://www.android.com/accessibility/live-transcribe/) is an
Android application that provides real-time captioning for people who are deaf 
or hard of hearing. This repository contains the Android client libraries for
communicating with Google's Cloud Speech API that are used in Live Transcribe.

The automatic speech recognition (ASR) module has the following features:

- Infinite streaming
- Support for [70+ languages](https://cloud.google.com/speech-to-text/docs/languages)
- Robust to brief network loss (which occurs often when traveling and switching
 between network/wifi). Text is not lost, only delayed.
- Robust to extended network loss. Will reconnect again even if network has been
 out for hours. Of course, no speech recognition can be delivered without a
 connection.
- Robust to server errors
- Opus, AMR-WB, FLAC encoding can be easily enabled and configured.
- Contains a text formatting library for visualizing ASR confidence, speaker
 ID, and more
- Extensible to offline models
- Built-in support for speech detectors, which can be used to stop ASR during
 extended silences to save money and data (Note that speech detector
 implementation is not provided)
- Built-in support for speaker identification, which can be used to label or
 color text according to speaker number (Note that speaker identification
 implementation is not provided)

The libraries provided are nearly identical to those running in the production
application Live Transcribe. They have been extensively field tested and unit
tested. However, the tests themselves are not open sourced at this time.

Contact lt-speech-engine-maintainers@google.com with questions/issues.

To try this library out using our sample Android application, follow the
instructions below. These instructions assume that the host operating 
system is an Ubuntu-like flavor of Linux. If other operating systems can be 
supported with reasonable, additional efforts we may do so on a case-by-case 
basis, however we unfortunately cannot claim that this library will be maintained 
across all operating systems and build environments. Sorry for any inconvenience.
See note below about testing this on other environments.

We have also provided APKs so that you can try out the library without building
any code.

Whether you're using our code or our sample APKs, an API key is required. See the
[documentation on API keys](https://cloud.google.com/docs/authentication/api-keys)
to learn more. In the sample APK, you can copy/paste your API key into the pop-up
dialog.


```
Requirements: CMake, Gradle, Android SDK/NDK
(1) Export the path of your Android SDK. The NDK is assumed to be located at
   $ANDROID_SDK_PATH/ndk-bundle [Android NDK](https://developer.android.com/ndk/guides)
   export ANDROID_SDK_PATH="/wherever/your/sdk/is"
(2) Build the APKs (location is app/build/outputs/apk/)
   ./build_all.sh
```

# What this library does (and important tricks for getting good results):

The purpose of this library is to simulate an infinite connection to Google's
Cloud Speech API. The API itself currently does not support infinite streaming
and forces a timeout after 5 minutes of streaming. It turns out that there are a
lot of subtleties involved in covering up this timeout, and we believe that not
everyone should have to figure this out on their own. The main logic for
managing streaming requests is the RepeatingRecognitionSession class. This class
maintains a single bidirectional streaming request, called a session, and takes
measures to avoid hitting the timeout. Namely, we use the following strategies:
- Try to close sessions during pauses once the server-side timeout time is
approaching (this is done using the is_final field from the returned speech
results as they are an estimate of when a pause has happened).
- Close sessions that have been silent for a very long time prior to hitting the
timeout. If someone were to start talking, it is better that that be towards the
beginning of the session.
- Store a buffer of audio in between sessions and send it once the new session
starts. The device may jump from one network to another, or from network to
WiFi. Even on a steady connection, it can take more than the typical hundred or
so milliseconds to open a new session after the previous one has closed. This
buffer is crucial for making sure all audio gets to the server.

## Model selection
In most cases, the [best model](https://cloud.google.com/speech-to-text/docs/transcription-model)
to use for general purpose recognition is the default model. For languages where
it is available, the "video" model has much better performance.

```
// As seen in CloudSpeechSession.java
RecognitionConfig.Builder.newBuilder()
    .setModel("video")
    ...  // Other options.
    .build()
```

At the time of writing this, the video model exists only for the "en-US" locale
and is offered at a different price point.

Note that [server performance](https://issuetracker.google.com/issues/137672586)
can have a serious impact on result quality.

## Codec notes
There are other concerns that arise when trying to stream infinitely. In some
countries, data is expensive and sending uncompressed PCM formatted audio is
simply not practical. At 16kHz, streaming uncompressed 16-bit PCM data requires
256 kilobits per second of data, ignoring the comparatively small overhead of
header/auxiliary data. On low-bandwidth connections, this is too high of a data
rate to reliably use the cloud for recognition. It becomes necessary to use a
codec. Of the codecs supported by the speech APIs, we experimented with FLAC,
AMR-WB, and Opus (in an Ogg container). For the former two, we leverage the
Android framework's encoder. FLAC is a lossless codec (unlike most audio codecs)
and will get you roughly a factor of 2 in data compression. It introduces a few
hundred milliseconds of latency, but is quite acceptable in most cases. AMR-WB offers
a much more appealing compression ratio, but in relatively noisy conditions
performs very badly for speech recognition. We do not recommend using AMR-WB for
speech recognition under any circumstances.

Finally, the Opus codec delivers quite impressive results for speech
recognition. Unfortunately, the Android framework does not ship with an Opus
encoder, so we included a native implementation in our library.
At rates at least as low as 24 kilobits per second (a compression
ratio of nearly 11), recognition quality does not seem to be impacted at all. We
know that with captions, accuracy is critical, so in Live Transcribe, we
configured our Opus codec to use a more conservative 32 kbps with variable
bitrate (VBR) enabled. This is sufficient for minimizing data streaming costs
(note that music streaming services use bitrates many times higher than this).
However, there is still a bit of latency associated with Opus compression. There
is one more fairly technical detail that we use to minimize latency in our Opus
stream. For every block of audio that is pushed into the Ogg/Opus stream, we
flush the Ogg stream rather than let the ogg library decide on its own when to
push out the next block of data. This causes a slight increase in bitrate, but
a significant reduction in latency. For the curious, deep in our encoder is a
"low_latency_mode" flag. As a user of this library nothing need be done to
enable that. Just request the following settings for your
CloudSpeechSessionParams:

```
CloudSpeechSessionParams.newBuilder()
        .setEncoderParams(CloudSpeechSessionParams.EncoderParams.newBuilder()
            .setEnableEncoder(true)
            .setAllowVbr(true)
            .setCodec(CodecAndBitrate.OGG_OPUS_BITRATE_32KBPS))
        .build()
```

## Running on different environments
We expect that our code will build easily on Ubuntu, but on other systems, you 
might meet challenges building the c++ Opus library. Fortunately you can 
learn a lot about this library without using Opus at all. Here are some 
instructions for how to do so. They aren't extremely elegant, so please bear
in mind that we provide this info with the goal of getting you unblocked on
a system that we do not claim support for.

If you change the line [here](https://github.com/google/live-transcribe-speech-engine/blob/master/app/src/main/java/com/google/audio/MainActivity.java#L180) to request uncompressed audio, you will no longer have a dependency on Opus. 
```
CloudSpeechSessionParams.newBuilder()
        .setEncoderParams(CloudSpeechSessionParams.EncoderParams.newBuilder()
            .setEnableEncoder(false)
        .build()
```

Comment out the [the static import of the Opus lib](https://github.com/google/live-transcribe-speech-engine/blob/master/app/src/main/java/com/google/audio/StreamingAudioEncoder.java#L541). 

Your code no longer depends on Opus, but that doesn't mean the gradle files won't look for those deps.
Go through the gradle files and comment out any references to the c++ libs. 

For development and local testing, Opus vs. uncompressed audio doesn't matter 
much. It's nearly enough to decide whether these libraries suit your needs, so you 
can postpone figuring out Opus for when you decide whether to put your application
into production.

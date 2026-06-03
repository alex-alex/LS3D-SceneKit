#ifndef OggVorbisDecoder_h
#define OggVorbisDecoder_h

#include <stdbool.h>

typedef struct {
	int channels;
	int sampleRate;
	int frameCount;
	float *samples;
} OggVorbisDecodedAudio;

typedef struct OggVorbisStream OggVorbisStream;

bool OggVorbisDecodeFile(const char *path, OggVorbisDecodedAudio *audio);
void OggVorbisFreeDecodedAudio(OggVorbisDecodedAudio *audio);

OggVorbisStream *OggVorbisStreamOpen(const char *path);
void OggVorbisStreamClose(OggVorbisStream *stream);
int OggVorbisStreamGetChannels(OggVorbisStream *stream);
int OggVorbisStreamGetSampleRate(OggVorbisStream *stream);
int OggVorbisStreamGetFrameCount(OggVorbisStream *stream);
float OggVorbisStreamGetDuration(OggVorbisStream *stream);
int OggVorbisStreamRead(OggVorbisStream *stream, float **channelData, int frameCapacity);
bool OggVorbisStreamSeekStart(OggVorbisStream *stream);
bool OggVorbisStreamSeek(OggVorbisStream *stream, int frame);

#endif

#ifndef OggVorbisDecoder_h
#define OggVorbisDecoder_h

#include <stdbool.h>

typedef struct {
	int channels;
	int sampleRate;
	int frameCount;
	float *samples;
} OggVorbisDecodedAudio;

bool OggVorbisDecodeFile(const char *path, OggVorbisDecodedAudio *audio);
void OggVorbisFreeDecodedAudio(OggVorbisDecodedAudio *audio);

#endif

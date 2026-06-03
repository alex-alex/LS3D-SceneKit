#include "OggVorbisDecoder.h"

#include <limits.h>
#include <stdlib.h>

extern int stb_vorbis_decode_filename(const char *filename, int *channels, int *sample_rate, short **output);

bool OggVorbisDecodeFile(const char *path, OggVorbisDecodedAudio *audio) {
	if (path == NULL || audio == NULL) {
		return false;
	}

	int channels = 0;
	int sampleRate = 0;
	short *decodedSamples = NULL;
	int frameCount = stb_vorbis_decode_filename(path, &channels, &sampleRate, &decodedSamples);
	if (frameCount <= 0 || channels <= 0 || sampleRate <= 0 || decodedSamples == NULL) {
		free(decodedSamples);
		return false;
	}

	if (frameCount > INT_MAX / channels) {
		free(decodedSamples);
		return false;
	}

	int sampleCount = frameCount * channels;
	float *samples = malloc(sizeof(float) * (size_t)sampleCount);
	if (samples == NULL) {
		free(decodedSamples);
		return false;
	}

	for (int index = 0; index < sampleCount; index++) {
		samples[index] = (float)decodedSamples[index] / 32768.0f;
	}
	free(decodedSamples);

	audio->channels = channels;
	audio->sampleRate = sampleRate;
	audio->frameCount = frameCount;
	audio->samples = samples;
	return true;
}

void OggVorbisFreeDecodedAudio(OggVorbisDecodedAudio *audio) {
	if (audio == NULL) {
		return;
	}
	free(audio->samples);
	audio->channels = 0;
	audio->sampleRate = 0;
	audio->frameCount = 0;
	audio->samples = NULL;
}

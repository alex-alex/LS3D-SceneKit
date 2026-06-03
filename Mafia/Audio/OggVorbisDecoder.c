#include "OggVorbisDecoder.h"

#include <limits.h>
#include <stdlib.h>

typedef struct stb_vorbis stb_vorbis;
typedef struct {
	unsigned int sample_rate;
	int channels;
	unsigned int setup_memory_required;
	unsigned int setup_temp_memory_required;
	unsigned int temp_memory_required;
	int max_frame_size;
} stb_vorbis_info;

extern int stb_vorbis_decode_filename(const char *filename, int *channels, int *sample_rate, short **output);
extern stb_vorbis *stb_vorbis_open_filename(const char *filename, int *error, const void *alloc_buffer);
extern stb_vorbis_info stb_vorbis_get_info(stb_vorbis *f);
extern void stb_vorbis_close(stb_vorbis *f);
extern unsigned int stb_vorbis_stream_length_in_samples(stb_vorbis *f);
extern float stb_vorbis_stream_length_in_seconds(stb_vorbis *f);
extern int stb_vorbis_get_samples_float(stb_vorbis *f, int channels, float **buffer, int num_samples);
extern int stb_vorbis_seek_start(stb_vorbis *f);
extern int stb_vorbis_seek(stb_vorbis *f, unsigned int sample_number);

struct OggVorbisStream {
	stb_vorbis *vorbis;
	int channels;
	int sampleRate;
	int frameCount;
	float duration;
};

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

OggVorbisStream *OggVorbisStreamOpen(const char *path) {
	if (path == NULL) {
		return NULL;
	}

	int error = 0;
	stb_vorbis *vorbis = stb_vorbis_open_filename(path, &error, NULL);
	if (vorbis == NULL) {
		return NULL;
	}

	stb_vorbis_info info = stb_vorbis_get_info(vorbis);
	if (info.channels <= 0 || info.sample_rate == 0) {
		stb_vorbis_close(vorbis);
		return NULL;
	}

	OggVorbisStream *stream = malloc(sizeof(OggVorbisStream));
	if (stream == NULL) {
		stb_vorbis_close(vorbis);
		return NULL;
	}

	stream->vorbis = vorbis;
	stream->channels = info.channels;
	stream->sampleRate = (int)info.sample_rate;
	stream->frameCount = (int)stb_vorbis_stream_length_in_samples(vorbis);
	stream->duration = stb_vorbis_stream_length_in_seconds(vorbis);
	return stream;
}

void OggVorbisStreamClose(OggVorbisStream *stream) {
	if (stream == NULL) {
		return;
	}
	if (stream->vorbis != NULL) {
		stb_vorbis_close(stream->vorbis);
	}
	free(stream);
}

int OggVorbisStreamGetChannels(OggVorbisStream *stream) {
	return stream == NULL ? 0 : stream->channels;
}

int OggVorbisStreamGetSampleRate(OggVorbisStream *stream) {
	return stream == NULL ? 0 : stream->sampleRate;
}

int OggVorbisStreamGetFrameCount(OggVorbisStream *stream) {
	return stream == NULL ? 0 : stream->frameCount;
}

float OggVorbisStreamGetDuration(OggVorbisStream *stream) {
	return stream == NULL ? 0 : stream->duration;
}

int OggVorbisStreamRead(OggVorbisStream *stream, float **channelData, int frameCapacity) {
	if (stream == NULL || stream->vorbis == NULL || channelData == NULL || frameCapacity <= 0) {
		return 0;
	}
	return stb_vorbis_get_samples_float(stream->vorbis, stream->channels, channelData, frameCapacity);
}

bool OggVorbisStreamSeekStart(OggVorbisStream *stream) {
	if (stream == NULL || stream->vorbis == NULL) {
		return false;
	}
	return stb_vorbis_seek_start(stream->vorbis) != 0;
}

bool OggVorbisStreamSeek(OggVorbisStream *stream, int frame) {
	if (stream == NULL || stream->vorbis == NULL) {
		return false;
	}
	if (frame < 0) {
		frame = 0;
	}
	if (stream->frameCount > 0 && frame > stream->frameCount) {
		frame = stream->frameCount;
	}
	return stb_vorbis_seek(stream->vorbis, (unsigned int)frame) != 0;
}

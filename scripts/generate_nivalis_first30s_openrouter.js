const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const serverDir = path.join(root, 'server');
require(path.join(serverDir, 'node_modules', 'dotenv')).config({ path: path.join(serverDir, '.env') });

const videoService = require(path.join(serverDir, 'dist', 'src', 'services', 'openrouter-video.service.js'));

const seriesDir = path.join(root, 'series_bibles', 'nivalis-memorias-de-gelo');
const promptPath = path.join(seriesDir, 'episode01_first30s_openrouter_seedance25.md');
const resultPath = path.join(seriesDir, 'episode01_first30s_openrouter_seedance25_result.json');

const referenceUrls = [
  'https://pub-ea9841fef0bb48b8ba58fd0e872de7f5.r2.dev/references/nivalis/seedance25-30s-20260809/lys.png',
  'https://pub-ea9841fef0bb48b8ba58fd0e872de7f5.r2.dev/references/nivalis/seedance25-30s-20260809/noa.png',
  'https://pub-ea9841fef0bb48b8ba58fd0e872de7f5.r2.dev/references/nivalis/seedance25-30s-20260809/tarik.png',
  'https://pub-ea9841fef0bb48b8ba58fd0e872de7f5.r2.dev/references/nivalis/seedance25-30s-20260809/banco-termico.png',
];

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const promptFromMarkdown = (markdown) => {
  const match = markdown.match(/## Prompt enviado à API\s+```text\s*([\s\S]*?)\s*```/);
  if (!match) throw new Error('Bloco de prompt não encontrado.');
  return match[1].trim();
};

const writeResult = (value) => {
  fs.writeFileSync(resultPath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
};

(async () => {
  process.chdir(serverDir);
  const prompt = promptFromMarkdown(fs.readFileSync(promptPath, 'utf8'));
  const request = {
    provider: 'openrouter',
    model: 'bytedance/seedance-2.5',
    label: 'nivalis-ep01-first30s-seedance25-480p',
    prompt,
    duration: 30,
    resolution: '480p',
    aspectRatio: '9:16',
    seed: 260809,
    generateAudio: true,
    uploadLastFrame: false,
    inputReferenceUrls: referenceUrls,
  };

  console.log('Submitting OpenRouter Seedance 2.5 job...');
  const submitted = await videoService.submitVideoJob(request);
  const jobId = submitted?.openrouter?.id || submitted?.id;
  if (!jobId) throw new Error(`OpenRouter não retornou job id: ${JSON.stringify(submitted)}`);

  const result = {
    createdAt: new Date().toISOString(),
    request: {
      model: request.model,
      duration: request.duration,
      resolution: request.resolution,
      aspectRatio: request.aspectRatio,
      seed: request.seed,
      generateAudio: request.generateAudio,
      referenceUrls,
      promptPath,
    },
    jobId,
    submit: submitted.openrouter || submitted,
    status: 'pending',
  };
  writeResult(result);
  console.log(`JOB_ID=${jobId}`);

  for (let attempt = 1; attempt <= 120; attempt += 1) {
    if (attempt > 1) await sleep(30_000);
    const statusBody = await videoService.getVideoJobStatus({ provider: 'openrouter' }, jobId);
    const status = String(statusBody?.status || statusBody?.data?.status || 'unknown').toLowerCase();
    result.status = status;
    result.lastStatus = statusBody;
    result.lastPollAt = new Date().toISOString();
    result.pollAttempts = attempt;
    writeResult(result);
    console.log(`POLL=${attempt} STATUS=${status}`);

    if (status === 'completed') {
      const downloaded = await videoService.downloadVideoJob({
        provider: 'openrouter',
        jobId,
        label: request.label,
        uploadLastFrame: false,
      });
      result.download = downloaded;
      result.completedAt = new Date().toISOString();
      writeResult(result);
      console.log(`VIDEO_PATH=${downloaded.files.videoPath}`);
      console.log(`LAST_FRAME_PATH=${downloaded.files.framePath}`);
      return;
    }

    if (['failed', 'cancelled', 'canceled', 'error'].includes(status)) {
      throw new Error(`Job terminou com status ${status}: ${JSON.stringify(statusBody)}`);
    }
  }

  throw new Error('Polling esgotado sem conclusão.');
})().catch((error) => {
  const failure = {
    failedAt: new Date().toISOString(),
    error: error?.message || String(error),
    stack: error?.stack,
  };
  try {
    const previous = fs.existsSync(resultPath) ? JSON.parse(fs.readFileSync(resultPath, 'utf8')) : {};
    writeResult({ ...previous, ...failure, status: 'failed' });
  } catch {
    writeResult({ ...failure, status: 'failed' });
  }
  console.error(failure.error);
  process.exit(1);
});

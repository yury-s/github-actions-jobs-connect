// @ts-check
import {DefaultArtifactClient} from '@actions/artifact'
import * as core from '@actions/core'
import { execSync } from 'child_process';



const name = core.getInput('name', { required: true, trimWhitespace: true });
const outputDir = core.getInput('path', { required: true, trimWhitespace: true });

const client = new DefaultArtifactClient();

async function waitAndDownload() {
  const { artifact } = await client.getArtifact(name);
  await client.downloadArtifact(artifact.id, { path: outputDir });
  console.log('Downloaded artifact to', outputDir);
}

console.log('Trying to download artifact', name);
while (true) {
  try {
    await waitAndDownload();
    break;
  } catch (e) {
    console.log('Error downloading artifact', e.message);
  }
  await new Promise(resolve => setTimeout(resolve, 200));
}

execSync('ls -l ' + outputDir, { stdio: 'inherit' });
execSync('cat ' + outputDir + '/' + name, { stdio: 'inherit' });
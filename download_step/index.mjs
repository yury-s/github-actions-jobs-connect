// @ts-check
import {DefaultArtifactClient} from '@actions/artifact'

const name = process.argv[2];
const outputDir = process.argv[3];

console.log('Trying to download artifact', name);
const client = new DefaultArtifactClient();
const { artifact } = await client.getArtifact(name);
await client.downloadArtifact(artifact.id, { path: outputDir });
console.log('Downloaded artifact to', outputDir);

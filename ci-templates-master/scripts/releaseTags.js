import fs from 'fs';
import simpleGit from 'simple-git';

console.log('Starting release tags script.');

const git = simpleGit().outputHandler((bin, _, __, args) => console.log('$', bin, ...args));
const { all: tags } = await git.tags();
const packages = fs
	.readdirSync('packages')
	.map(pkg => JSON.parse(fs.readFileSync(`packages/${pkg}/package.json`)));

for (const { name, version } of packages) {
	const [major, minor, patch] = version.split('.');
	const tagMajor = `${name}@${major}`;
	const tagMinor = `${name}@${major}.${minor}`;
	const tagPatch = `${name}@${major}.${minor}.${patch}`;

	// Create tags only if new version for package is released
	if (!tags.includes(tagPatch)) {
		console.log(`Creating tags for ${name}`);

		await git.tag([tagPatch]);
		await git.pushTags('origin', [tagPatch]);
		await git.tag([tagMinor, '--force']);
		await git.pushTags('origin', [tagMinor, '--force']);
		await git.tag([tagMinor, '--force']);
		await git.pushTags('origin', [tagMajor, '--force']);
	} else {
		console.log(`No tags created for ${name}`);
	}
}

console.log('Done!');

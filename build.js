// Creates zip files for each package
// Creates a manifest.json with info about all packages
// Each package in packages folder has a package.json

const fs = require("fs");
const path = require("path");
const archiver = require("archiver");

const buildPath = path.join(__dirname, "build");
const packagesPath = path.join(__dirname, "packages");
const manifest = [];

fs.mkdirSync(buildPath, { recursive: true });

fs.readdirSync(packagesPath).forEach((packageName) => {
  const packagePath = path.join(packagesPath, packageName);
  const packageJson = require(path.join(packagePath, "package.json"));
  const zipPath = path.join(buildPath, `${packageName}.zip`);

  const output = fs.createWriteStream(zipPath);
  const archive = archiver("zip", {
    zlib: { level: 9 },
  });

  archive.pipe(output);
  // add the directory, except for the package.json
  const glob = ["**/*", "!package.json", `!${packageJson.icon}`];
  archive.glob(glob, { cwd: packagePath, dot: true });
  archive.finalize();

  const manifestEntry = {
    name: packageJson.name,
    version: packageJson.version,
    description: packageJson.description,
    zipPath: `${packageName}.zip`,
  };

  if (fs.existsSync(path.join(packagePath, packageJson.icon))) {
    // Copy icon to build folder with new name
    manifestEntry.icon = `${packageName}_icon.png`;
    fs.copyFileSync(
      path.join(packagePath, packageJson.icon),
      path.join(buildPath, `${packageName}_icon.png`)
    );
  }

  manifest.push(manifestEntry);
});

fs.writeFileSync(
  path.join(buildPath, "manifest.json"),
  JSON.stringify(manifest, null, 2)
);

console.log("Build complete");

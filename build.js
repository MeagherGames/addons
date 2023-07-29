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
  const glob = ["**/*", "!package.json"];
  archive.glob(glob, { cwd: packagePath, dot: true });
  archive.finalize();

  manifest.push({
    name: packageJson.name,
    version: packageJson.version,
    description: packageJson.description,
    icon: packageJson.icon,
    zipPath: `${packageName}.zip`,
  });
});

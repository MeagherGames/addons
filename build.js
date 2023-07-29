// Creates zip files for each package
// Creates a manifest.json with info about all packages
// Each package in packages folder has a package.json

const fs = require("fs");
const path = require("path");
const archiver = require("archiver");

const buildPath = path.join(__dirname, "build");
const packagesPath = path.join(__dirname, "packages");
const manifest = [];
let category_id = 1;
const categories = {
  project: {},
  addon: {
    "Misc": 0,
  },
};

fs.mkdirSync(buildPath, { recursive: true });

fs.readdirSync(packagesPath).forEach((packageName) => {
  const packagePath = path.join(packagesPath, packageName);
  const packageJson = require(path.join(packagePath, "package.json"));

  const requiredFields = ["name", "version", "description", "godotVersion"];
  requiredFields.forEach((field) => {
    if (!packageJson[field]) {
      throw new Error(`Missing required field "${field}" in "${packageName}" package.json`);
    }
  });

  const zipPath = path.join(buildPath, `${packageName}.zip`);

  const output = fs.createWriteStream(zipPath);
  const archive = archiver("zip", {
    zlib: { level: 9 },
  });

  archive.pipe(output);
  // add the directory, except for the package.json
  const glob = `**/!(package.json|${packageJson.icon})*`;
  archive.glob(glob, { cwd: packagePath, dot: true });
  archive.finalize();

  const categoryType = packageJson.isProject ? "project" : "addon";
  // Configure category info
  if (packageJson.category) {
    if (!categories[categoryType][packageJson.category]) {
      categories[categoryType][packageJson.category] = category_id;
      category_id += 1;
    }
  }

  const manifestEntry = {
    name: packageJson.name,
    version: packageJson.version,
    description: packageJson.description,
    zipPath: `${packageName}.zip`,
    category: packageJson.category || "Misc",
    categoryId: categories[categoryType][packageJson.category || "Misc"],
    godotVersion: packageJson.godotVersion,
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

fs.writeFileSync(
  path.join(buildPath, "categories.json"),
  JSON.stringify(categories, null, 2)
);

console.log("Build complete");

// Creates zip files for each addon
// Creates a manifest.json with info about all addons
// Each addon in addons folder has a addon.json

const fs = require("fs");
const path = require("path");
const archiver = require("archiver");

const buildPath = path.join(process.cwd(), "build");
const addonsPath = path.join(process.cwd(), "addons");
const manifest = [];
let category_id = 2;
const categories = {
  project: {},
  addon: {
    Misc: 1,
  },
};

function includeDependencies(root, addonJson, archive) {
  if (Array.isArray(addonJson.dependencies)) {
    addonJson.dependencies.forEach((dependency) => {
      
      // Get the base path of the dependency
      const pathParts = path.normalize(dependency).split(path.sep);
      const dependencyName = pathParts.shift();
      const dependencyBasePath = path.join(
        addonsPath,
        dependencyName
      );
      dependency = path.posix.join(...pathParts);
      if (dependency === ".") {
        dependency = "**/*";
      }
      const dependencyJson = require(path.join(
        dependencyBasePath,
        "addon.json"
      ));
      
      // add to fold in zip with name of addon
      archive.glob(
        dependency,
        { cwd: dependencyBasePath, dot: true, ignore: ["addon.json"] },
        { prefix: root }
      );
      includeDependencies(root, dependencyJson, archive);
    });
  }
}

fs.mkdirSync(buildPath, { recursive: true });

fs.readdirSync(addonsPath).forEach((addonName) => {
  const addonPath = path.join(addonsPath, addonName);
  const addonJson = require(path.join(addonPath, "addon.json"));

  const requiredFields = ["name", "version", "description", "godotVersion"];
  requiredFields.forEach((field) => {
    if (!addonJson[field]) {
      throw new Error(
        `Missing required field "${field}" in "${addonName}" addon.json`
      );
    }
  });

  const zipPath = path.join(buildPath, `${addonName}.zip`);

  const output = fs.createWriteStream(zipPath);
  const archive = archiver("zip", {
    zlib: { level: 9 },
  });

  archive.pipe(output);
  // add to fold in zip with name of addon
  archive.glob(
    "**/*",
    { cwd: addonPath, dot: true, ignore: ["addon.json"] },
    { prefix: addonName }
  );

  // Handle addon dependencies
  includeDependencies(addonName, addonJson, archive);

  archive.finalize();

  const categoryType = addonJson.isProject ? "project" : "addon";
  // Configure category info
  if (addonJson.category) {
    if (!categories[categoryType][addonJson.category]) {
      categories[categoryType][addonJson.category] = category_id;
      category_id += 1;
    }
  }

  const manifestEntry = {
    name: addonJson.name,
    version: addonJson.version,
    description: addonJson.description,
    zipPath: `${addonName}.zip`,
    category: addonJson.category || "Misc",
    categoryId: categories[categoryType][addonJson.category || "Misc"],
    godotVersion: addonJson.godotVersion,
  };

  if (fs.existsSync(path.join(addonPath, addonJson.icon))) {
    // Copy icon to build folder with new name
    manifestEntry.icon = `${addonName}_icon.png`;
    fs.copyFileSync(
      path.join(addonPath, addonJson.icon),
      path.join(buildPath, `${addonName}_icon.png`)
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

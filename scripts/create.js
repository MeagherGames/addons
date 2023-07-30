const readline = require("readline");
const fs = require("fs");

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

const ask = (question, defaultValue = "") => {
  return new Promise((resolve, reject) => {
    const q = `${question}${defaultValue ? ` (${defaultValue})` : ""}: `;
    rl.question(q, (answer) => {
      resolve(answer || defaultValue);
    });
  });
};
const create = async () => {
  const name = await ask("Addon name");
  const packageJson = {
    name,
    description: await ask("Addon description", name),
    category: await ask("Category", "Misc"),
    godotVersion: await ask("Godot version", "4.1"),
    version: await ask("Version", "1.0.0"),
    icon: "Icon.png",
  };
  const addonPath = `packages/${name}`;
  fs.mkdirSync(addonPath, { recursive: true });

  fs.writeFileSync(
    `${addonPath}/package.json`,
    JSON.stringify(packageJson, null, 4)
  );
  if (fs.existsSync("scripts/Icon.png")) {
    fs.copyFileSync("scripts/Icon.png", `${addonPath}/Icon.png`);
  }

  console.log(`Addon ${name} created`);
};

create()
  .catch((err) => {
    console.error(err);
    rl.close();
    process.exit(1);
  })
  .finally(() => {
    rl.close();
  });

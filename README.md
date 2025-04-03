# Addons
MeagherGames addons for Godot Engine
Pushing changes to the main branch will automatically create a new release.
> 📌 **Note:** This repository is maintained as a personal project. There is no obligation or guarantee of support, maintenance, or feature development for external users.


## Pre-requisites
- [Node.js](https://nodejs.org/en/download/)

## Install dependencies
```bash
npm install
```

## Create a new addon
```bash
npm run create
```
When creating an addon, the root directory of that addon is like the root directory of the Godot Engine project it'll be used in. So if you want anything in a folder say `addons/MyAddon` you'll need to create that folder structure yourself.


## Build
```bash
npm run build
```
This will create a `build` folder that will be used in the release.

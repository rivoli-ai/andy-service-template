// Copyright (c) Rivoli AI 2026. All rights reserved.
// Licensed under the Apache License, Version 2.0.

using System.CommandLine;
using __SERVICE_PASCAL__.Cli.Commands;

var rootCommand = new RootCommand("__SERVICE_DISPLAY__ CLI - Manage __SERVICE_KEBAB__ resources");

var apiUrlOption = new Option<string>(
    "--api-url",
    getDefaultValue: () => "https://localhost:__PORT_HTTPS__",
    description: "The __SERVICE_DISPLAY__ API base URL");
rootCommand.AddGlobalOption(apiUrlOption);

var tokenOption = new Option<string?>(
    "--token",
    description: "Bearer token for authentication");
rootCommand.AddGlobalOption(tokenOption);

// Item commands
var itemsCommand = new Command("items", "Manage items");
ItemCommands.Register(itemsCommand, apiUrlOption, tokenOption);
rootCommand.AddCommand(itemsCommand);

return await rootCommand.InvokeAsync(args);

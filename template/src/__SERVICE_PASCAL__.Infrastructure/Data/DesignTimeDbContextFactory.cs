// Copyright (c) Rivoli AI 2026. All rights reserved.
// Licensed under the Apache License, Version 2.0.

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace __SERVICE_PASCAL__.Infrastructure.Data;

public class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optionsBuilder.UseNpgsql("Host=localhost;Port=__PORT_PG__;Database=__SERVICE_SNAKE__;Username=__SERVICE_SNAKE__;Password=__SERVICE_SNAKE___dev_password");
        return new AppDbContext(optionsBuilder.Options);
    }
}

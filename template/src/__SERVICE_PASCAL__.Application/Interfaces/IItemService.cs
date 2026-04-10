// Copyright (c) Rivoli AI 2026. All rights reserved.
// Licensed under the Apache License, Version 2.0.

using __SERVICE_PASCAL__.Application.Dtos;

namespace __SERVICE_PASCAL__.Application.Interfaces;

public interface IItemService
{
    Task<IEnumerable<ItemDto>> GetAllAsync(CancellationToken ct = default);
    Task<ItemDto?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<ItemDto> CreateAsync(CreateItemRequest request, string userId, CancellationToken ct = default);
    Task<ItemDto?> UpdateAsync(Guid id, CreateItemRequest request, CancellationToken ct = default);
    Task<bool> DeleteAsync(Guid id, CancellationToken ct = default);
}

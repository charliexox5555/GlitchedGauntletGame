# Render Shop weapon artwork

Use Draft Duels (place `71551303511506`) in Studio Edit. The batch lists contain 228 Shop skins for each view, plus 18 Stock side icons. Each line is one 3 × 2 sheet from the actual Studio models. The PopCircuit Bat uses the Knife name for portraits and Bat for side icons.

1. Enable **View → Show UI** and turn off **View → Show View Selector**. Select desktop HD 1080 in Device Simulator. Run this in Studio Edit to capture a native 5760 × 2880 viewport, including the part extending beyond the window.

   ```luau
   local sim = game:GetService("StudioDeviceSimulatorService")
   sim:SetResolutionAsync(5760, 2880)
   sim:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
   game:GetService("StarterGui").ShowDevelopmentGui = true
   ```

2. Run the following PowerShell in the repository to prepare each Studio command. Set `$kind` to `portrait` or `side` and `$batch` to the one-based line number. Paste the generated source into the Edit Command Bar or pass it to Studio MCP's Edit `execute_luau`.

   ```powershell
   $kind = 'portrait'
   $batch = 1
   $listPath = if ($kind -eq 'portrait') { 'round2_shop_portraits.txt' } else { 'round2_shop_sides.txt' }
   $items = (Get-Content "tools/render/portrait-lists/$listPath")[$batch - 1]
   $modelList = '{ ' + (($items.Split(';') | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ' }'
   if ($kind -eq 'portrait') {
       (Get-Content -Raw tools/studio/RenderPortraits.luau).Replace(
           'local LIST: { string } = {}', "local LIST: { string } = $modelList"
       ).Replace('local COLS, ROWS = 2, 2', 'local COLS, ROWS = 3, 2')
   } else {
       'local render = (function()'
       Get-Content -Raw tools/studio/RenderItemIcons.luau
       "end)(); return render($modelList, false, 3, 2)"
   }
   ```

3. Verify the renderer reports no missing models. Use **View → Screenshot** (default shortcut **Clear**) for the black PNG. Then run the line below, allow the viewport to refresh, and take the white PNG without moving the camera or changing the grid. Copy those two named Studio screenshots to the temporary folder below as `black.png` and `white.png`. The Roblox screenshot directory is normally in Windows Pictures.

   ```luau
   game:GetService("StarterGui")._IconSheet.BG.BackgroundColor3 = Color3.new(1, 1, 1)
   ```

4. Cut the two lossless captures into transparent PNGs. The cutter rejects undersized artwork and foreground on a cell boundary. For a crop that is too small, rerun the affected models in a larger cell and pass the same grid dimensions to the cutter.

   ```powershell
   $render = Join-Path $env:TEMP 'gg-shop-round2'
   $black = Join-Path $render 'black.png'
   $white = Join-Path $render 'white.png'
   $out = Join-Path $render $kind
   if ($kind -eq 'portrait') {
       python tools/render/icon_sheet.py $black $white $out $items --cols 3 --rows 2 --centered --square --minw 768 --maxw 1024
   } else {
       python tools/render/icon_sheet.py $black $white $out $items --cols 3 --rows 2 --centered --cell-aspect 1.4222222222 --minw 1024 --maxw 1024
   }
   ```

5. After checking the completed batches, copy the transparent renders into `art-source/ui/item-portraits/` and `art-source/ui/item-icons/` and upload each via the existing uploader. Keep the printed Decal IDs paired with their filenames. Review any in-progress files at those paths before replacing them.

   ```powershell
   foreach ($kind in 'portrait', 'side') {
       $assets = if ($kind -eq 'portrait') { 'art-source/ui/item-portraits' } else { 'art-source/ui/item-icons' }
       Get-ChildItem -LiteralPath (Join-Path $render $kind) -Filter '*.png' -File | ForEach-Object {
           $destination = Join-Path $assets $_.Name
           Copy-Item -LiteralPath $_.FullName -Destination $destination
           $id = python tools/opencloud/upload_asset.py --group 11116787 --type Decal $destination "GG $kind $($_.BaseName)"
           if ($LASTEXITCODE -ne 0) { throw "Upload failed for $destination" }
           Add-Content -LiteralPath (Join-Path $render 'decals.tsv') -Value "$kind`t$($_.BaseName)`t$id"
       }
   }
   ```

6. For each small batch of Decal IDs, run the following in Studio Edit and use the returned image IDs in `src/shared/ItemPortraits.luau` and `src/shared/ItemIcons.luau`. The image IDs differ from the Decal IDs. Rerun `tools/studio/AuditShopArt.luau` after syncing both maps and `ShopCatalog` to Studio.

   ```luau
   local ids = {} -- Decal ids from decals.tsv
   local insert = game:GetService("InsertService")
   local result = {}
   for _, id in ids do
       local model = insert:LoadAsset(id)
       local decal = model:FindFirstChildWhichIsA("Decal", true)
       local texture = if decal then decal.Texture else ""
       model:Destroy()
       assert(texture ~= "", "Decal " .. id .. " has no texture")
       table.insert(result, tostring(id) .. "\t" .. texture)
   end
   return table.concat(result, "\n")
   ```

7. Remove the temporary sheet before saving the place, restore the simulator and the View selector, and restore fullscreen and Output dock as needed.

   ```luau
   local starterGui = game:GetService("StarterGui")
   local sheet = starterGui:FindFirstChild("_IconSheet")
   if sheet then sheet:Destroy() end
   starterGui.ShowDevelopmentGui = false
   game:GetService("StudioDeviceSimulatorService"):StopSimulationAsync()
   ```

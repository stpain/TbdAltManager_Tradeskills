

local addonName, TbdAltManagerTradeskills = ...;

local playerUnitToken = "player";
local Tradeskills = TbdAltManagerTradeskills.Tradeskills;

local TradeskillArtworkPath = [[Interface\AddOns\TbdAltManager_Tradeskills\Media\Tradeskills]]

local TbcTradeskillSpellIDs = {}

local function GenerateDataDiffForTBC()
    for spellID, itemID in pairs(TbdAltManagerTradeskills.Data.Tbc.SpellIdToReagents) do
        if not TbdAltManagerTradeskills.Data.Classic.SpellIdToReagents[spellID] then
            TbcTradeskillSpellIDs[spellID] = true
        end
    end
end

local function GenerateTradeskillDataForID(tradeskillID)
    local tradeskillRecipeSpellIDs = {}
    local added = {}
    for spellID, id in pairs(TbdAltManagerTradeskills.Data.Classic.SpellIdToTradeskillId) do
        if id == tradeskillID then
            if TbdAltManagerTradeskills.Data.Classic.SpellIdToReagents[spellID] then
                if not added[spellID] then
                    table.insert(tradeskillRecipeSpellIDs, {
                        spellID = spellID,
                        isLearned = IsPlayerSpell(spellID),
                    })
                    added[spellID] = true
                end
            end
        end
    end
    return tradeskillRecipeSpellIDs

    --return Tradeskills:GetTradeskillSpellIDs(tradeskillID)
end



--Callback registry
TbdAltManagerTradeskills.CallbackRegistry = CreateFromMixins(CallbackRegistryMixin)
TbdAltManagerTradeskills.CallbackRegistry:OnLoad()
TbdAltManagerTradeskills.CallbackRegistry:GenerateCallbackEvents({
    "Character_OnAdded",
    "Character_OnChanged",
    "Character_OnRemoved",
    "DataProvider_OnInitialized",
    "OnTradeskillSelected"
})



local characterDefaults = {
    uid = "",
    profession1 = false,
    profession1Data = {},
    profession2 = false,
    profession2Data = {},
    archaeology = {},
    fishing = {},
    cooking = {},
    firstAid = {},
}


--Main DataProvider for the module
local CharacterDataProvider = CreateFromMixins(DataProviderMixin)

function CharacterDataProvider:InsertCharacter(characterUID)

    local character = self:FindElementDataByPredicate(function(characterData)
        return (characterData.uid == characterUID)
    end)

    if not character then        
        local newCharacter = {}
        for k, v in pairs(characterDefaults) do
            newCharacter[k] = v
        end

        newCharacter.uid = characterUID

        self:Insert(newCharacter)
        TbdAltManagerTradeskills.CallbackRegistry:TriggerEvent("Character_OnAdded")
    end
end

function CharacterDataProvider:FindCharacterByUID(characterUID)
    return self:FindElementDataByPredicate(function(character)
        return (character.uid == characterUID)
    end)
end

function CharacterDataProvider:UpdateDefaultKeys()
    for _, character in self:EnumerateEntireRange() do
        for k, v in pairs(characterDefaults) do
            if character[k] == nil then
                character[k] = v;
            end
        end
    end
end





TbdAltManagerTradeskills.Api = {}

function TbdAltManagerTradeskills.Api.EnumerateCharacters()
    return CharacterDataProvider:EnumerateEntireRange()
end

function TbdAltManagerTradeskills.Api.GetCharacterDataByUID(characterUID)
    return CharacterDataProvider:FindElementDataByPredicate(function(character)
        return (character.uid == characterUID)
    end)
end

function TbdAltManagerTradeskills.Api.DeleteCharacterByCharacterUID(characterUID)
    CharacterDataProvider:RemoveByPredicate(function(character)
        return (character.uid == characterUID)
    end)
    TbdAltManagerTradeskills.CallbackRegistry:TriggerEvent("Character_OnRemoved", characterUID)
end


function TbdAltManagerTradeskills.Api.SearchFor(searchTerm)

    local ret = {}

    for _, character in CharacterDataProvider:EnumerateEntireRange() do

        if character.profession1Data and character.profession1Data.categories then

            for expansionName, info in pairs(character.profession1Data.categories) do

                if info.recipes then
                    for _, recipeInfo in ipairs(info.recipes) do
                        if recipeInfo.name:find(searchTerm, nil, true) then

                            if not ret[recipeInfo.recipeID] then
                                ret[recipeInfo.recipeID] = {
                                    name = recipeInfo.name,
                                    professionID = info.professionID,
                                    professionName = info.professionName,
                                    parentProfessionID = info.parentProfessionID,
                                    parentProfessionName = info.parentProfessionName,

                                    crafters = {},
                                }
                            end
                            table.insert(ret[recipeInfo.recipeID].crafters, character.uid)
                        end
                    end
                end
            end
        end

    end


    return ret;
end

function TbdAltManagerTradeskills.Api.GetTradeskillDataForTradeskillID(tradeskillID)
    
    local ret = {}

    for _, character in CharacterDataProvider:EnumerateEntireRange() do

        if tradeskillID == 185 then
            if type(character.cooking) == "table" then
                table.insert(ret, {
                    characterUID = character.uid,
                    data = character.cooking
                })
            end
        end

        if character.profession1 == tradeskillID then
            table.insert(ret, {
                characterUID = character.uid,
                categories = character.profession1Data.categories
            })
        end

        if character.profession2 == tradeskillID then
            table.insert(ret, {
                characterUID = character.uid,
                categories = character.profession2Data.categories
            })
        end
    end

    return ret;
end






local eventsToRegister = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "SKILL_LINES_CHANGED",
}

--Frame to setup event listening
local TradeskillsEventFrame = CreateFrame("Frame")
for _, event in ipairs(eventsToRegister) do
    TradeskillsEventFrame:RegisterEvent(event)
end
TradeskillsEventFrame:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)


function TradeskillsEventFrame:ResetCharacterData(characterUID)
    local character = CharacterDataProvider:FindCharacterByUID(characterUID)
    if character then
        for k, v in pairs(characterDefaults) do
            character[k] = v
        end
        self:ScanTradeskills()
        TbdAltManagerTradeskills.CallbackRegistry:TriggerEvent("Character_OnChanged")
    end
end

function TradeskillsEventFrame:ScanTradeskills()

    if not self.character then
        return
    end

    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()

    local skills = self:GetPlayerSkillLevels()
    for skillID, skillLevel in pairs(skills) do
        
        --first aid
        if skillID == 129 then
            
        end
        --cooking
        if skillID == 185 then
            
        end
        --fishing
        if skillID == 356 then
            
        end

        if (skillID ~= 129) and (skillID ~= 185) and (skillID ~= 356) then

            if self.character.profession1 == self.character.profession2 then
                self.character.profession1 = false;
                self.character.profession1Data = {}
                self.character.profession2 = false;
                self.character.profession2Data = {}
            end

            if type(self.character.profession1) == "number" then
                if not skills[self.character.profession1] then
                    self.character.profession1 = false;
                    self.character.profession1Data = {}
                end
            end

            if type(self.character.profession2) == "number" then
                if not skills[self.character.profession2] then
                    self.character.profession2 = false;
                    self.character.profession2Data = {}
                end
            end

            if self.character.profession1 == false then
                self.character.profession1 = skillID
            end

            if self.character.profession1 == skillID then
                local tradeskillRecipeSpells = GenerateTradeskillDataForID(skillID)
                self.character.profession1Data = {
                    name = Tradeskills:GetLocaleNameFromID(skillID),
                    categories = {
                        {
                            name = "Classic",
                            recipes = tradeskillRecipeSpells,
                            level = skillLevel,
                        }
                    }
                }
            end

            if type(self.character.profession1) == "number" and (self.character.profession1 ~= skillID) then
                self.character.profession2 = skillID
            end

            if self.character.profession2 == skillID then
                local tradeskillRecipeSpells = GenerateTradeskillDataForID(skillID)
                self.character.profession2Data = {
                    name = Tradeskills:GetLocaleNameFromID(skillID),
                    categories = {
                        {
                            name = "Classic",
                            recipes = tradeskillRecipeSpells,
                            level = skillLevel,
                        }
                    }
                }
            end

        end
    end

end

--https://warcraft.wiki.gg/wiki/API_C_TradeSkillUI.GetRecipeSchematic
function TradeskillsEventFrame:GetRecipeReagentData(recipe)
    
end

function TradeskillsEventFrame:SetKeyValue(key, value)
    if self.character then
        self.character[key] = value;
        TbdAltManagerTradeskills.CallbackRegistry:TriggerEvent("Character_OnChanged", self.character)
        --print("triggered event")
    end
end

function TradeskillsEventFrame:SetTradeskillData(tradeskillData)
    if self.character then


        TbdAltManagerTradeskills.CallbackRegistry:TriggerEvent("Character_OnChanged", self.character)
    end
end

function TradeskillsEventFrame:ADDON_LOADED(...)
    if (... == addonName) then


        if TbdAltManagerTradeskillsConfig == nil then
            TbdAltManagerTradeskillsConfig = {
                recipeSpellDataLoaded = false,
            }
        end


        if TbdAltManager_Tradeskills_SavedVariables == nil then

            CharacterDataProvider:Init({})
            TbdAltManager_Tradeskills_SavedVariables = CharacterDataProvider:GetCollection()
    
        else
    
            local data = TbdAltManager_Tradeskills_SavedVariables
            CharacterDataProvider:Init(data)
            TbdAltManager_Tradeskills_SavedVariables = CharacterDataProvider:GetCollection()
    
        end

        CharacterDataProvider:UpdateDefaultKeys()

        if not CharacterDataProvider:IsEmpty() then
            TbdAltManagerTradeskills.CallbackRegistry:TriggerEvent("DataProvider_OnInitialized")
        end



        RecipeSpellData = {}
        for spellID, itemID in pairs(TbdAltManagerTradeskills.Data.Classic.SpellIdToReagents) do

            RecipeSpellData[spellID] = {
                name = TbdAltManagerTradeskills.Data.Classic.SpellIDToName[spellID],
                spellID = spellID,
                reagents = {},
                createdItemID = TbdAltManagerTradeskills.Data.Classic.SpellIdToItemCreated[spellID],
            }
            local data = TbdAltManagerTradeskills.Data.Classic.SpellIdToReagents[spellID]
            if data then
                for i = 1, 8 do
                    if data[i+8] > 0 then
                        RecipeSpellData[spellID].reagents[data[i]] = data[i+8]
                    end
                end
            end
        end

    end
end

function TradeskillsEventFrame:PLAYER_ENTERING_WORLD()
    local account = "Default"
    local realm = GetRealmName()
    local name = UnitName(playerUnitToken)

    self.characterUID = string.format("%s.%s.%s", account, realm, name)

    CharacterDataProvider:InsertCharacter(self.characterUID)

    self.character = CharacterDataProvider:FindCharacterByUID(self.characterUID)

    self:ScanTradeskills()

    if ViragDevTool_AddData then
        ViragDevTool_AddData(TbdAltManager_Tradeskills_SavedVariables, addonName)
    end
end

function TradeskillsEventFrame:SKILL_LINES_CHANGED()
    self:ScanTradeskills()
end

function TradeskillsEventFrame:GetPlayerSkillLevels()
    local skills = {}
    for s = 1, GetNumSkillLines() do
        local skill, _, _, level, _, _, _, _, _, _, _, _, _ = GetSkillLineInfo(s)
        if skill and (type(level) == "number") then
            local tradeskillId = Tradeskills:GetTradeskillIDFromLocale(skill)
            if tradeskillId then
                skills[tradeskillId] = level
            end
        end
    end
    return skills;
end












TbdAltManagerTradeskillReagentButtonMixin = {}
function TbdAltManagerTradeskillReagentButtonMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    GameTooltip:Show()
end
function TbdAltManagerTradeskillReagentButtonMixin:OnLeave()
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
end














TbdAltManagerTradeskillsTreeviewItemTemplateMixin = {}
function TbdAltManagerTradeskillsTreeviewItemTemplateMixin:OnLoad()
    self:SetScript("OnLeave", function()
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    end)
end

function TbdAltManagerTradeskillsTreeviewItemTemplateMixin:UpdateToggledTextures(node)
    if node:IsCollapsed() then
        self.ParentRight:SetAtlas("Options_ListExpand_Right")
    else
        self.ParentRight:SetAtlas("Options_ListExpand_Right_Expanded")
    end
end

local r1, g1, b1 = COMMON_GRAY_COLOR:GetRGB()
local r2, g2, b2 = ARTIFACT_BAR_COLOR:GetRGB()
function TbdAltManagerTradeskillsTreeviewItemTemplateMixin:SetDataBinding(binding, height, node)
    
    self:SetHeight(height)

    if binding.isParent then
        self.ParentLeft:Show()
        self.ParentRight:Show()
        self.ParentMiddle:Show()

        self:SetScript("OnMouseDown", function(_, button)
            if button == "RightButton" then
                --context menu
            else
                node:ToggleCollapsed()
                self:UpdateToggledTextures(node)
            end
        end)

    else
        self.Background:SetColorTexture(0,0,0,0)
        if binding.index then
            if binding.index % 2 == 0 then
                self.Background:SetColorTexture(r1, g1, b1, 0.12)
            else
                self.Background:SetColorTexture(r2, g2, b2, 0.12)
            end
        end
    end

    if binding.label then
        self.LinkLabel:SetText(binding.label)
    end

    if binding.showStatusBar then
        self.StatusBar:SetMinMaxValues(binding.statusBarData.min, binding.statusBarData.max)
        self.StatusBar:SetValue(binding.statusBarData.val)
        self.StatusBar:Show()
        self.StatusBar.level:SetText(string.format("%s / %s", binding.statusBarData.val, binding.statusBarData.max))
    else
        self.StatusBar:Hide()
    end

    if binding.name then
        self.LinkLabel:SetText(binding.name)
    end

    if binding.spellID then
        self:SetScript("OnEnter", function()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(binding.spellID)
            GameTooltip:Show()
        end)

        if binding.isLearned then
            self.LinkLabel:SetText(string.format("%s %s", CreateAtlasMarkup("common-icon-checkmark", 20, 20), binding.name))
        else
            self.LinkLabel:SetText(string.format("%s %s", CreateAtlasMarkup("common-icon-redx", 20, 20), binding.name))
        end

    end

    if binding.reagents then
        if not self.reagentButtons then
            self.reagentButtons = CreateFramePool("Button", self, "TbdAltManagerTradeskillReagentButtonTemplate", function(_, but)
                but:SetText("")
                but.Icon:SetTexture(nil)
                but:Hide()
                but:ClearAllPoints()

                but.itemID = nil
            end)
        end

        local lastButton;
        for itemID, count in pairs(binding.reagents) do
            local button = self.reagentButtons:Acquire()
            local icon = select(5, C_Item.GetItemInfoInstant(itemID))
            button.Icon:SetTexture(icon)
            button.Label:SetText(count)
            button.itemID = itemID
            button:Show()
            if not lastButton then
                button:SetPoint("RIGHT", 0, 0)
                lastButton = button
            else
                button:SetPoint("RIGHT", lastButton, "LEFT", -3, 0)
                lastButton = button
            end
        end
    else

    end

end
function TbdAltManagerTradeskillsTreeviewItemTemplateMixin:ResetDataBinding()
    self.ParentLeft:Hide()
    self.ParentRight:Hide()
    self.ParentMiddle:Hide()

    self.Icon:SetTexture(nil)

    self:SetScript("OnMouseDown", nil)
    self:SetScript("OnEnter", nil)

    self.LinkLabel:SetText("")

    self.Background:SetTexture(nil)

    self.DeleteTradeskillButton:SetScript("OnClick", nil)
    self.DeleteTradeskillButton:Hide()

    if self.reagentButtons then
        self.reagentButtons:ReleaseAll()
    end
end










TbdAltManagerTradeskillsMenuChildMixin = {}
function TbdAltManagerTradeskillsMenuChildMixin:SetDataBinding(binding, height)

end
function TbdAltManagerTradeskillsMenuChildMixin:ResetDataBinding()
    
end











local menuEntryChildren = {}
local locale = GetLocale()
for n, id in pairs(Tradeskills.PrimaryTradeskills) do
    table.insert(menuEntryChildren, {
        height = 22,
        template = "TbdAltManagerTradeskillsMenuChildTemplate",
        initializer = function(frame)
            frame.Icon:SetAtlas(Tradeskills:TradeskillIDToAtlas(id))
            frame.Label:SetText(Tradeskills.TradeskillIDsToLocaleName[locale][id])
            frame:SetScript("OnMouseUp", function()
                TbdAltsManager.Api.SelectModule("Tradeskills")
                TbdAltManagerTradeskills.CallbackRegistry:TriggerEvent("OnTradeskillSelected", id)
            end)
        end,
    })
end


--need to just keep a ref to the button to set a script later
local MenuEntryToggleButton;

TbdAltManagerTradeskillsMixin = {
    name = "Tradeskills",
    menuEntry = {
        height = 40,
        template = "TbdAltManagerSideBarListviewItemTemplate",
        initializer = function(frame)
            frame.Label:SetText("Tradeskills")
            frame.Icon:SetAtlas("Vehicle-HammerGold")
            frame:SetScript("OnMouseUp", function()
                TbdAltsManager.Api.SelectModule("Tradeskills")
            end)
            MenuEntryToggleButton = frame.ToggleButton
            TbdAltsManager.Api.SetupSideMenuItem(frame, true, true)
        end,
    },
}

function TbdAltManagerTradeskillsMixin:OnLoad()
    TbdAltsManager.Api.RegisterModule(self)

    for _, entry in ipairs(menuEntryChildren) do
        self.menuEntryNode:Insert(entry)
    end

    self.menuEntryNode:ToggleCollapsed()

    MenuEntryToggleButton:SetScript("OnClick", function()
        self.menuEntryNode:ToggleCollapsed()
    end)

    TbdAltManagerTradeskills.CallbackRegistry:RegisterCallback("OnTradeskillSelected", self.OnTradeskillSelected, self)
end


local SortFunc = function(a, b)
    return a:GetData().name < b:GetData().name
end

function TbdAltManagerTradeskillsMixin:OnTradeskillSelected(tradeskillID)

    self.selectedTradeskillID = tradeskillID
    
    local charactersWithTradeskillData = TbdAltManagerTradeskills.Api.GetTradeskillDataForTradeskillID(tradeskillID)

    self.dataProvider = CreateTreeDataProvider()
    self.dataProvider:Init({})
    self.Treeview.scrollView:SetDataProvider(self.dataProvider)

    --DevTools_Dump(charactersWithTradeskillData)

    for _, data in ipairs(charactersWithTradeskillData) do
        local characterNode = self.dataProvider:Insert({
            isParent = true,
            label = data.characterUID,
        })

        if data.categories then
            for _, category in ipairs(data.categories) do
                
                local categoryNode = characterNode:Insert({
                    isParent = true,
                    label = category.name,
                    showStatusBar = true,
                    statusBarData = {
                        min = 1,
                        max = 300,
                        val = category.level,
                    }
                })


                if TbdAltManagerTradeskillsConfig.recipeSpellDataLoaded == true then

                    local t = {}

                    for k, recipe in ipairs(category.recipes) do

                        local data = RecipeSpellData[recipe.spellID]
                        if data then
                            table.insert(t, data)
                        end

                        t[#t].isLearned = recipe.isLearned

                    end

                    table.sort(t, function(a, b)
                        if a.isLearned == b.isLearned then
                            return a.name < b.name
                        else
                            return a.isLearned and not b.isLearned
                        end
                    end)

                    for k, recipe in ipairs(t) do
                        recipe.index = k
                        categoryNode:Insert(recipe)
                    end

                    --categoryNode:SetSortComparator(SortFunc, true, true)
                    categoryNode:ToggleCollapsed()
                    --categoryNode:Sort()
                end

            end
        end
    end

end
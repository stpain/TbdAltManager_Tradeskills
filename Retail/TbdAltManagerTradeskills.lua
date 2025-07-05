

local addonName, TbdAltManagerTradeskills = ...;

local playerUnitToken = "player";
local Tradeskills = TbdAltManagerTradeskills.Tradeskills;


--Callback registry
TbdAltManagerTradeskills.CallbackRegistry = CreateFromMixins(CallbackRegistryMixin)
TbdAltManagerTradeskills.CallbackRegistry:OnLoad()
TbdAltManagerTradeskills.CallbackRegistry:GenerateCallbackEvents({
    "Character_OnAdded",
    "Character_OnChanged",
    "Character_OnRemoved",
    "OnTradeskillSelected",
    "DataProvider_OnInitialized",
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







--Expose some api via the namespace
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



--[[
    bit awkward at the moment

    this returns a table as such

    t[recipeID] = {
        name
        professionID
        professionName
        parentProfessionID 
        parentProfessionName
        crafters = {
            characterUID
        }
    }
]]
function TbdAltManagerTradeskills.Api.SearchFor(searchTerm)

    local ret = {}

    for _, character in CharacterDataProvider:EnumerateEntireRange() do

        if character.profession1Data and character.profession1Data.categories then

            for profID, info in pairs(character.profession1Data.categories) do

                if info.recipeData then
                    for _, recipeInfo in ipairs(info.recipeData) do
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

        if character.profession2Data and character.profession2Data.categories then

            for profID, info in pairs(character.profession2Data.categories) do

                if info.recipeData then
                    for _, recipeInfo in ipairs(info.recipeData) do
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

function TbdAltManagerTradeskills.Api.GetTradeskillDataForParentID(parentID)
    
    local ret = {}

    for _, character in CharacterDataProvider:EnumerateEntireRange() do

        if parentID == 185 then
            if type(character.cooking) == "table" then
                table.insert(ret, {
                    characterUID = character.uid,
                    data = character.cooking
                })
            end
        end

        if character.profession1 == parentID then
            table.insert(ret, {
                characterUID = character.uid,
                data = character.profession1Data
            })
            -- local isMatch = true;
            -- for expID, info in pairs(character.profession1Data.categories) do
            --     if info.parentProfessionID ~= parentID then
            --         isMatch = false;
            --     end
            -- end
            -- if isMatch then
            --     table.insert(ret, {
            --         characterUID = character.uid,
            --         data = character.profession1Data
            --     }) 
            -- end
        end

        if character.profession2 == parentID then
            table.insert(ret, {
                characterUID = character.uid,
                data = character.profession2Data
            }) 
            local isMatch = true;
            -- for expID, info in pairs(character.profession2Data.categories) do
            --     if info.parentProfessionID ~= parentID then
            --         isMatch = false;
            --     end
            -- end
            -- if isMatch then
            --     table.insert(ret, {
            --         characterUID = character.uid,
            --         data = character.profession2Data
            --     }) 
            -- end
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

function TradeskillsEventFrame:InitializeCharacter()
    
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

    EventRegistry:RegisterCallback("Professions.SelectSkillLine", function(fooID, info)

        self:ScanTradeskills()

        local tradeskillData = {}

        for k, v in pairs(info) do
            tradeskillData[k] = v
        end

        tradeskillData.recipeData = {}
        
        --local frameData
        C_Timer.After(1.0, function()

            --[[
                after trying several ways this seems to work best
            ]]

            for k, element in ProfessionsFrame.CraftingPage.RecipeList.ScrollBox:GetDataProvider():EnumerateEntireRange() do

                if element.data and element.data.recipeInfo then
                    local capture = {}
                    capture.recipeID = element.data.recipeInfo.recipeID
                    capture.name = element.data.recipeInfo.name
                    capture.categoryID = element.data.recipeInfo.categoryID
                    capture.hyperlink = element.data.recipeInfo.hyperlink
                    capture.icon = element.data.recipeInfo.icon
                    capture.learned = element.data.recipeInfo.learned
                    capture.maxTrivialLevel = element.data.recipeInfo.maxTrivialLevel
                    capture.relativeDifficulty = element.data.recipeInfo.relativeDifficulty

                    table.insert(tradeskillData.recipeData, capture)
                end
            end

            -- ProfessionsFrame.CraftingPage.RecipeList.ScrollBox:ForEachFrame(function(frame)
            --     frameData = frame:GetData()
            --     if frameData.recipeInfo then

            --         local capture = {}
            --         capture.recipeID = frameData.recipeInfo.recipeID
            --         capture.name = frameData.recipeInfo.name
            --         capture.categoryID = frameData.recipeInfo.categoryID
            --         capture.hyperlink = frameData.recipeInfo.hyperlink
            --         capture.icon = frameData.recipeInfo.icon
            --         capture.learned = frameData.recipeInfo.learned
            --         capture.maxTrivialLevel = frameData.recipeInfo.maxTrivialLevel
            --         capture.relativeDifficulty = frameData.recipeInfo.relativeDifficulty

            --         table.insert(tradeskillData.recipeData, capture)

            --     end
            -- end)

            -- for _, id in pairs(C_TradeSkillUI.GetAllRecipeIDs()) do
            --     local recipeInfo = C_TradeSkillUI.GetRecipeInfo(id)
            --     local capture = {}
            --     capture.recipeID = recipeInfo.recipeID
            --     capture.name = recipeInfo.name
            --     capture.categoryID = recipeInfo.categoryID
            --     capture.hyperlink = recipeInfo.hyperlink
            --     capture.icon = recipeInfo.icon
            --     capture.learned = recipeInfo.learned
            --     capture.maxTrivialLevel = recipeInfo.maxTrivialLevel
            --     capture.relativeDifficulty = recipeInfo.relativeDifficulty

            --     table.insert(tradeskillData.recipeData, capture)
            -- end

            if ViragDevTool_AddData then
                ViragDevTool_AddData(tradeskillData, tradeskillData.parentTradeSkillID)
            end

            self:SetTradeskillData(tradeskillData)
        end)

    end)

end

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

    --local tempDataProf1, tempDataProf2 = self.character.profession1Data, self.character.profession2Data;

    if self.character.profession1 == false then
        if prof1 then
            self:SetKeyValue("profession1", select(7, GetProfessionInfo(prof1)))
        end
    else
        local id = select(7, GetProfessionInfo(prof1))
        if self.character.profession1 ~= id then
            self.character.profession1Data = {}
        end
    end

    if self.character.profession2 == false then
        if prof2 then
            self:SetKeyValue("profession2", select(7, GetProfessionInfo(prof2)))
        end
    else
        local id = select(7, GetProfessionInfo(prof2))
        if self.character.profession2 ~= id then
            self.character.profession2Data = {}
        end
    end



    -- if archaeology then
    --     self:SetKeyValue("archaeology", select(7, GetProfessionInfo(archaeology)))
    -- end
    -- if fishing then
    --     self:SetKeyValue("fishing", select(7, GetProfessionInfo(fishing)))
    -- end
    -- if cooking then
    --     self:SetKeyValue("cooking", select(7, GetProfessionInfo(cooking)))
    -- end
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

        if tradeskillData.parentProfessionID == 185 then

            --remove for release
            if type(self.character.cooking) ~= "table" then
                self.character.cooking = {}
            end
            
            if not self.character.cooking.name then
                self.character.cooking = {
                    name = tradeskillData.parentProfessionName,
                    categories = {}
                }
            end

            self.character.cooking.categories[tradeskillData.professionID] = tradeskillData;
        end

        if self.character.profession1 == tradeskillData.parentProfessionID then

            if not self.character.profession1Data.name then
                self.character.profession1Data = {
                    name = tradeskillData.parentProfessionName,
                    categories = {}
                }
            end

            self.character.profession1Data.categories[tradeskillData.professionID] = tradeskillData;
        end

        if self.character.profession2 == tradeskillData.parentProfessionID then

            if not self.character.profession2Data.name then
                self.character.profession2Data = {
                    name = tradeskillData.parentProfessionName,
                    categories = {}
                }
            end

            self.character.profession2Data.categories[tradeskillData.professionID] = tradeskillData;
        end

        TbdAltManagerTradeskills.CallbackRegistry:TriggerEvent("Character_OnChanged", self.character)
    end
end

function TradeskillsEventFrame:ADDON_LOADED(...)
    if (... == addonName) then
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
    end
end

function TradeskillsEventFrame:PLAYER_ENTERING_WORLD()
    C_Timer.After(1.0, function()
        self:InitializeCharacter()
    end)
end

function TradeskillsEventFrame:SKILL_LINES_CHANGED()
    self:ScanTradeskills()
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
                self.Background:SetColorTexture(0,0,0,0.1)
            else
                self.Background:SetColorTexture(0.5,0.5,0.5,0.1)
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

    if binding.recipeData then

        if binding.recipeData.hyperlink then

            self:SetScript("OnEnter", function()
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetHyperlink(binding.recipeData.hyperlink)
                GameTooltip:Show()
            end)

            if binding.recipeData.learned then
                self.LinkLabel:SetText(string.format("%s %s", CreateAtlasMarkup("common-icon-checkmark", 20, 20), binding.recipeData.hyperlink))
            else
                self.LinkLabel:SetText(string.format("%s %s", CreateAtlasMarkup("common-icon-redx", 20, 20), binding.recipeData.hyperlink))
            end

        else
            if binding.recipeData.learned then
                self.LinkLabel:SetText(string.format("%s %s", CreateAtlasMarkup("common-icon-checkmark", 20, 20), binding.recipeData.name))
            else
                self.LinkLabel:SetText(string.format("%s %s", CreateAtlasMarkup("common-icon-redx", 20, 20), binding.recipeData.name))
            end

        end

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

    MenuEntryToggleButton:SetScript("OnClick", function(button)
        self.menuEntryNode:ToggleCollapsed()
        if self.menuEntryNode:IsCollapsed() then
            button:SetNormalAtlas("128-RedButton-Plus")
            button:SetPushedAtlas("128-RedButton-Plus-Pressed")
        else
            button:SetNormalAtlas("128-RedButton-Minus")
            button:SetPushedAtlas("128-RedButton-Minus-Pressed")
        end
    end)

    TbdAltManagerTradeskills.CallbackRegistry:RegisterCallback("OnTradeskillSelected", self.OnTradeskillSelected, self)

    self:SetNewDataProvider()

    self.treeviewNodes = {}

    self.SearchEditBox.ok:SetScript("OnClick", function()
        self:SearchForItem(self.SearchEditBox:GetText())
    end)
    self.SearchEditBox:SetScript("OnEnterPressed", function(editbox)
        self:SearchForItem(editbox:GetText())
    end)
    self.SearchEditBox.cancel:SetScript("OnClick", function(editbox)
        editbox:SetText("")
        self.Treeview.scrollView:SetDataProvider(self.dataProvider)
    end)


    TbdAltManagerTradeskills.CallbackRegistry:RegisterCallback("Character_OnAdded", self.Character_OnAdded, self)
    TbdAltManagerTradeskills.CallbackRegistry:RegisterCallback("Character_OnChanged", self.Character_OnChanged, self)
    TbdAltManagerTradeskills.CallbackRegistry:RegisterCallback("Character_OnRemoved", self.Character_OnRemoved, self)
end

function TbdAltManagerTradeskillsMixin:OnTradeskillSelected(tradeskillID)
    self:LoadTradeskillData(tradeskillID)
end




function TbdAltManagerTradeskillsMixin:SetNewDataProvider()
    self.dataProvider = CreateTreeDataProvider()
    self.dataProvider:Init({})
    self.Treeview.scrollView:SetDataProvider(self.dataProvider)
end

function TbdAltManagerTradeskillsMixin:Character_OnRemoved(characterUID)
    self:SetNewDataProvider()
end

function TbdAltManagerTradeskillsMixin:SearchForItem(searchTerm)
    
    local tempDataProvider = CreateTreeDataProvider()
    tempDataProvider:Init({})
    self.Treeview.scrollView:SetDataProvider(tempDataProvider)

    local data = TbdAltManagerTradeskills.Api.SearchFor(searchTerm)

    --local account, realm, characterName = strsplit(".", info.characterUID)
    
    local nodes = {}
    for recipeID, info in pairs(data) do
                
        nodes[recipeID] = tempDataProvider:Insert({
            label = info.name,
            isParent = true,
        })

        for _, crafter in ipairs(info.crafters) do

            local account, realm, characterName = strsplit(".", crafter)

            nodes[recipeID]:Insert({
                label = characterName,
            })

        end
    end
end

function TbdAltManagerTradeskillsMixin:OnShow()

end


function TbdAltManagerTradeskillsMixin:Character_OnChanged(character)
    if self.treeviewNodes[character.uid] and self.selectedTradeskillID then
        if self.selectedTradeskillID == character.profession1 then
            
        elseif self.selectedTradeskillID == character.profession2 then


        else
            
        end
    end
end

function TbdAltManagerTradeskillsMixin:Character_OnAdded()

end

function TbdAltManagerTradeskillsMixin:LoadTradeskillData(tradeskillID)


    --[[
    
        TODO:
            add a category level to the view?
            C_TradeSkillUI.GetCategoryInfo() gets the subheader (child category "Axes" for example)

            reagents
            C_TradeSkillUI.GetRecipeInfo
            link = C_TradeSkillUI.GetRecipeFixedReagentItemLink(recipeID, dataSlotIndex)
            schematic = C_TradeSkillUI.GetRecipeSchematic(recipeSpellID, isRecraft [, recipeLevel])
    ]]

    self.selectedTradeskillID = tradeskillID

    --self.background:SetAtlas(tradeskillBackgrounds[tradeskillID])

    self:SetNewDataProvider()

    local data = TbdAltManagerTradeskills.Api.GetTradeskillDataForParentID(tradeskillID)

    self:LoadTreeviewData(data)

end

function TbdAltManagerTradeskillsMixin:LoadTreeviewData(data)
    self.treeviewNodes = {}

    for _, info in ipairs(data) do

        local account, realm, characterName = strsplit(".", info.characterUID)

        
        self.treeviewNodes[info.characterUID] = self.dataProvider:Insert({
            label = characterName,
            isParent = true,
        })


        if info.characterUID and info.data and info.data.categories then

            for childCategory, categoryData in pairs(info.data.categories) do
                self.treeviewNodes[info.characterUID][childCategory] = self.treeviewNodes[info.characterUID]:Insert({
                    label = categoryData.professionName,
                    isParent = true,

                    showStatusBar = true,
                    statusBarData = {
                        min = 1,
                        max = categoryData.maxSkillLevel,
                        val = categoryData.skillLevel,
                    }
                })
                self.treeviewNodes[info.characterUID][childCategory]:ToggleCollapsed()

                local numRecipes = #categoryData.recipeData
                if numRecipes > 0 then
                    local index = 1;
                    C_Timer.NewTicker(0.001, function()
                        if self.treeviewNodes and self.treeviewNodes[info.characterUID] and self.treeviewNodes[info.characterUID][childCategory] then
                            self.treeviewNodes[info.characterUID][childCategory]:Insert({
                                index = index,
                                recipeData = categoryData.recipeData[index],
                            })
                            index = index + 1;
                        end
                    end, numRecipes)
                end

            end

        end


    end
end


local addonName, addon = ...;

local playerUnitToken = "player";


--Global namespace for the module so addons can interact with it
TbdAltManager_Tradeskills = {}

--Callback registry
TbdAltManager_Tradeskills.CallbackRegistry = CreateFromMixins(CallbackRegistryMixin)
TbdAltManager_Tradeskills.CallbackRegistry:OnLoad()
TbdAltManager_Tradeskills.CallbackRegistry:GenerateCallbackEvents({
    "Character_OnAdded",
    "Character_OnChanged",
    "Character_OnRemoved",

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
        TbdAltManager_Tradeskills.CallbackRegistry:TriggerEvent("Character_OnAdded")
    end
end

function CharacterDataProvider:FindCharacterByUID(characterUID)
    return self:FindElementDataByPredicate(function(character)
        return (character.uid == characterUID)
    end)
end









--Expose some api via the namespace
TbdAltManager_Tradeskills.Api = {}

function TbdAltManager_Tradeskills.Api.EnumerateCharacters()
    return CharacterDataProvider:EnumerateEntireRange()
end

function TbdAltManager_Tradeskills.Api.GetCharacterDataByUID(characterUID)
    return CharacterDataProvider:FindElementDataByPredicate(function(character)
        return (character.uid == characterUID)
    end)
end


function TbdAltManager_Tradeskills.Api.GetTradeskillDataForParentID(parentID)
    
    local ret = {}

    for _, character in CharacterDataProvider:EnumerateEntireRange() do

        if character.profession1 == parentID then
            table.insert(ret, {
                characterUID = character.uid,
                data = character.profession1Data
            })
        end

        if character.profession2 == parentID then
            table.insert(ret, {
                characterUID = character.uid,
                data = character.profession2Data
            })
        end
    end

    return ret;
end







local eventsToRegister = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",


}

--Frame to setup event listening
local CharacterEventFrame = CreateFrame("Frame")
for _, event in ipairs(eventsToRegister) do
    CharacterEventFrame:RegisterEvent(event)
end
CharacterEventFrame:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

function CharacterEventFrame:SetKeyValue(key, value)
    if self.character then
        self.character[key] = value;
        TbdAltManager_Tradeskills.CallbackRegistry:TriggerEvent("Character_OnChanged", self.character)
        --print("triggered event")
    end
end

function CharacterEventFrame:SetTradeskillData(tradeskillData)
    if self.character then

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

        TbdAltManager_Tradeskills.CallbackRegistry:TriggerEvent("Character_OnChanged", self.character)
    end
end

function CharacterEventFrame:ADDON_LOADED(...)
    if (... == addonName) then
        if TbdAltManager_Tradeskills_SavedVariables == nil then

            CharacterDataProvider:Init({})
            TbdAltManager_Tradeskills_SavedVariables = CharacterDataProvider:GetCollection()
    
        else
    
            local data = TbdAltManager_Tradeskills_SavedVariables
            CharacterDataProvider:Init(data)
            TbdAltManager_Tradeskills_SavedVariables = CharacterDataProvider:GetCollection()
    
        end

        if not CharacterDataProvider:IsEmpty() then
            TbdAltManager_Tradeskills.CallbackRegistry:TriggerEvent("DataProvider_OnInitialized")
        end
    end
end

function CharacterEventFrame:PLAYER_ENTERING_WORLD()
    C_Timer.After(1.0, function()
        self:InitializeCharacter()
    end)
end

function CharacterEventFrame:InitializeCharacter()
    
    local account = "Default"
    local realm = GetRealmName()
    local name = UnitName(playerUnitToken)

    self.characterUID = string.format("%s.%s.%s", account, realm, name)

    CharacterDataProvider:InsertCharacter(self.characterUID)

    self.character = CharacterDataProvider:FindCharacterByUID(self.characterUID)

    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()

    if prof1 then
        self:SetKeyValue("profession1", select(7, GetProfessionInfo(prof1)))
    end
    if prof2 then
        self:SetKeyValue("profession2", select(7, GetProfessionInfo(prof2)))
    end

    if archaeology then
        self:SetKeyValue("archaeology", select(7, GetProfessionInfo(archaeology)))
    end
    if fishing then
        self:SetKeyValue("fishing", select(7, GetProfessionInfo(fishing)))
    end
    if cooking then
        self:SetKeyValue("cooking", select(7, GetProfessionInfo(cooking)))
    end

    if ViragDevTool_AddData then
        ViragDevTool_AddData(TbdAltManager_Tradeskills_SavedVariables, addonName)
    end

    EventRegistry:RegisterCallback("Professions.SelectSkillLine", function(fooID, info)

        local tradeskillData = {}

        for k, v in pairs(info) do
            tradeskillData[k] = v
        end

        tradeskillData.recipeData = {}
        
        --local frameData
        C_Timer.After(1.0, function()

            --ViragDevTool_AddData(ProfessionsFrame.CraftingPage.RecipeList.ScrollBox:GetDataProvider(), "DataProvider")

            for k, element in ProfessionsFrame.CraftingPage.RecipeList.ScrollBox:GetDataProvider():EnumerateEntireRange() do
                --ViragDevTool_AddData(element, k)

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
                ViragDevTool_AddData(tradeskillData, fooID)
            end

            self:SetTradeskillData(tradeskillData)
        end)

    end)

end

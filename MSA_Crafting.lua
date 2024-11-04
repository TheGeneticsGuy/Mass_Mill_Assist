
local Crafting = {};
MSA.Crafting = Crafting;

-- Useful globals I haven't put in a tablet yet...
local combiningStacks = false;
local record_next = false;
local repeat_tracking = false
local salvage_item_id = 0;

-- Method:          Crafting.Establish_Spells()
-- What it DoeS:    Builds the dictionary tables for all the profession spells supported
-- Purpose:         Ensure the UI features are only available at compatible profession spells.
-- Note:            The int value of all ids is the number of reagents that need to be processed in spell
Crafting.Establish_Spells = function()
    Crafting.Profs = {}
    Crafting.Profs.MillingSpells = {
        [444181] = 10, [382981] = 5, [382982] = 5, [382984] = 5,
        [382986] = 5, [382987] = 5, [382988] = 5, [382989] = 5,
        [382990] = 5, [382991] = 5, [382994] = 5
    }
    Crafting.Profs.Jewelcrafting = {
        [434018] = 5, [434020] = 3, [374627] = 5, [395696] = 3, [325248] = 5,
        [382973] = 5, [382975] = 5, [382977] = 5, [382978] = 5, [404740] = 3,
        [382979] = 5, [382980] = 5, [382995] = 5
    }
    Crafting.Profs.HerbalismRefine = {
        [438811] = 5, [438812] = 5, [391088] = 5, [391089] = 5
    }
    Crafting.Profs.Cooking = {
        [445117] = 5, [445127] = 5, [445118] = 5, [445119] = 5, [447869] = 5
    }
    Crafting.Profs.Alchemy = {
        [430315] = 20, [370748] = 5, [427214] = 5
    }
    Crafting.Profs.Tailoring = {
        [446926] = 5
    }
    Crafting.Profs.Engineering = {
        [447310] = 5, [447311] = 5
    }
    Crafting.Profs.Enchanting = {
        [470726] = 1, [445466] = 1
    }
    Crafting.Profs.Skinning = {
        [440929] = 5, [440937] = 5, [440938] = 5, [375731] = 5, [440934] = 5,
        [375763] = 5, [376612] = 5, [376613] = 5, [376614] = 5, [440942] = 5,
        [440943] = 5, [376611] = 5
    }
end


-- Method:          Crafting.Get_Reagent_Count_Spell ( int )
-- What it Does:    Returns the number of reagents needed for that crafting spell
-- Purpose:         When combining stacks, I want to always pick the lowest stack first, UNLESS it is small than the minimum stack size to craft
--                  Why? Well, what if 4 herbs are in an early bag slot, but 1 herb is in the final bag slot? I want to stakc the 4 first or else
--                  milling will keep erroring. In all other cases I combine smallest to largest.
Crafting.Get_Reagent_Count_Spell = function( craft_id )
    for spells in pairs ( Crafting.Profs ) do
        if Crafting.Profs[spells][craft_id] then
            return Crafting.Profs[spells][craft_id];
        end
    end
end

-- Method:          Crafting.CombineStacks ( list , int , bool , bool , int )
-- What it Does:    Determines which item is being processed, and then keeps the stacks refreshed so crafting can continue indefinitely.
-- Purpose:         Quality of life for crafting thousands.
Crafting.CombineStacks = function( scrapSlot , itemID , forced , restart_crafting , craft_id )
    if not combiningStacks or forced then
        combiningStacks = true;
        scrapSlot = scrapSlot or nil;
        if restart_crafting == nil then
            restart_crafting = false;
        end

        local lowestStack;
        local maxStackSize = 0  -- Placeholder til it gets replaced.
        local itemInfo;

        if not scrapSlot and ( C_TradeSkillUI.IsRecipeRepeating() or restart_crafting ) then
            scrapSlot , itemID = Crafting.GetSalveItemDetails( restart_crafting );
        end

        if scrapSlot then

            -- BLIZZ HAS AN ORDER OF CRAFTING PRIORITY
            -- * PLAYER BAGS
            -- * PLAYER REAGENT BAG
            -- * PLAYER BANK
            -- * PLAYER REAGENT BANK
            -- * PLAYER WARBAND (TABS IN ORDER)

            local default_stack_min = 5

            -- Let's review first the bags in the slots
            for bag = 0 , NUM_BAG_SLOTS + 1 do  -- Loop through all bags (0 is backpack, 1-4 are additional bags, +1 for reagent bag)
                for slot = 1, C_Container.GetContainerNumSlots( bag ) do

                    if scrapSlot[1] ~= bag or scrapSlot[2] ~= slot then
                        itemInfo = C_Container.GetContainerItemInfo( bag , slot )

                        if itemInfo and itemInfo.itemID == itemID then

                            maxStackSize = C_Item.GetItemMaxStackSizeByID(itemID);
                            default_stack_min = Crafting.Get_Reagent_Count_Spell(craft_id);

                            if lowestStack and lowestStack[3] > itemInfo.stackCount and lowestStack[3] >= default_stack_min then
                                lowestStack = { bag , slot , itemInfo.stackCount};
                            elseif not lowestStack then
                                lowestStack = { bag , slot , itemInfo.stackCount};
                            end

                        end
                    end
                end
            end

            if lowestStack then
                -- Now, let's combine all of the smallest stacks to biggest stacks.
                C_Container.PickupContainerItem( lowestStack[1] , lowestStack[2] );
                C_Container.PickupContainerItem( scrapSlot[1] , scrapSlot[2] );

                -- This can only be called WHEN already mass crafting or it will cause taint.
                if C_TradeSkillUI.IsRecipeRepeating() then
                    Crafting.Refresh_Crafting( craft_id , maxStackSize , scrapSlot[1] , scrapSlot[2] );
                end

                if (scrapSlot[3] + lowestStack[3]) < maxStackSize then
                    C_Timer.After ( 2 , function()
                        Crafting.CombineStacks( scrapSlot , itemID , true , restart_crafting , craft_id );  -- Cycle back through to collect ALL the items. There needs to be a slight delay between each item move due to Blizz's bag limitations with stacking.
                    end);
                    return;
                end
            elseif C_TradeSkillUI.IsRecipeRepeating() then
                Crafting.Refresh_Crafting( craft_id , C_Item.GetItemMaxStackSizeByID(itemID) , scrapSlot[1] , scrapSlot[2] );
            end
        end
    end
    combiningStacks = false;
    if restart_crafting and not C_TradeSkillUI.IsRecipeRepeating() then
        print("MSA: Crafting has ended prematurely. Please restart and crafting will continue nonstop." )
    end
end

-- Method:          Crafting.Refresh_Crafting( int , int , int , int )
-- What it Does:    Refreshes the Craft all/Mill All button
-- Purpose:         Useful so stacks don't run out.
Crafting.Refresh_Crafting = function( craft_id , maxStackSize , bag , slot )

    if ProfessionsFrame and ProfessionsFrame.CraftingPage.SchematicForm:IsVisible() then
        ProfessionsFrame.CraftingPage:CreateInternal(ProfessionsFrame.CraftingPage.SchematicForm:GetRecipeInfo().recipeID, ProfessionsFrame.CraftingPage:GetCraftableCount(), ProfessionsFrame.CraftingPage.SchematicForm:GetCurrentRecipeLevel())
    else
        maxStackSize = maxStackSize or 1000
        C_TradeSkillUI.CraftSalvage( craft_id , maxStackSize , ItemLocation:CreateFromBagAndSlot( bag , slot ))
    end

end

-- Method:          Crafting.GetSalveItemDetails( bool )
-- What it Does:    Determines the details of the item and slot the item is being processed/milled/prosected/etc, from
-- Purpose:         To replenish this stack, I need information. This also accomplishes accounting for the bug
--                  that Blizz has failed to fix in 2 expansions so far (DF and TWW) where even though you select a stack
--                  It mass mills the bag in order of slot position regardles (right and up in the bags). So, it will replenish
--                  First slot if it fails rather than the selected slot.
Crafting.GetSalveItemDetails = function( restart_crafting )

    local item;
    local item_id;

    if MSA.SC.g_item_id ~= 0 then
        item_id = MSA.SC.g_item_id;
    else
        item_id = salvage_item_id;
    end
    if ProfessionsFrame and ProfessionsFrame.CraftingPage.SchematicForm:IsVisible() then
        item = ProfessionsFrame.CraftingPage.SchematicForm:GetTransaction().salvageItem;
        if not item or type(item.debugItemID) ~= "number" then
            return;
        else
            item_id = item.debugItemID;
        end
    end


    -- This is failing, so add stacks to first slot (compensates for positioning bug of not crafting the item you selected, but first in slot)
    if restart_crafting then
        local item_detail = {}

        for bag = 0 , NUM_BAG_SLOTS + 1 do  -- Loop through all bags + reagent bag
            for slot = 1, C_Container.GetContainerNumSlots( bag ) do
                item_detail = C_Container.GetContainerItemInfo( bag , slot )

                if item_detail and item_detail.itemID == item_id then
                    return { bag , slot , item_detail.stackCount } , item_id;
                end
            end
        end

        -- Crafts the selected item in the salvage box.
    else
        local itemDetails;
        local stack_count = 0;

        -- This is technically better as it focuses on the actually selected herbs, not just first
        if item then
            itemDetails = item:GetItemLocation();
            if itemDetails then
                stack_count = C_Container.GetContainerItemInfo( itemDetails.bagID , itemDetails.slotIndex ).stackCount
            end
        else
            local stack_size, bag, slot = Crafting.GetFirstReagentSizeStack( item_id );
            if stack_size then
                itemDetails = {};
                itemDetails.bagID = bag;
                itemDetails.slotIndex = slot;
                stack_count = stack_size;
            end
        end

        if itemDetails then
            return { itemDetails.bagID , itemDetails.slotIndex , stack_count } , item_id;
        end
    end
end

-- Method:          Crafting.GetFirstReagentSizeStack( int )
-- What it Does:    Returns the stack count of the first slot in the bags where the reagent is
-- Purpose:         Need to know how many in the stack if going to initialize reagent stacking immediately.
Crafting.GetFirstReagentSizeStack = function( item_id )
    if not item_id then
        if MSA.SC.g_item_id ~= 0 then
            item_id = MSA.SC.g_item_id;
            salvage_item_id = MSA.SC.g_item_id;
        end
    end

    if ProfessionsFrame and ProfessionsFrame.CraftingPage.SchematicForm:IsVisible() then
        local item = ProfessionsFrame.CraftingPage.SchematicForm:GetTransaction().salvageItem;
        if not item or type(item.debugItemID) ~= "number" then
            return;
        else
            item_id = item.debugItemID;
        end
    end

    local item_info = {}

    for bag = 0 , NUM_BAG_SLOTS + 1 do  -- Loop through all bags + reagent bag
        if not count then
            for slot = 1, C_Container.GetContainerNumSlots( bag ) do
                item_info = C_Container.GetContainerItemInfo( bag , slot )

                if item_info and item_info.itemID == item_id then

                    return item_info.stackCount , bag , slot
                end
            end
        end
    end
    return
end

-- Method:          Crafting.Get_Remaining_Count_Bags(int)
-- What it Does:    Returns the count of all the items in the player bags based on given item_id
--                  Or, it defaults to the selected salvage item ID being crafted.
-- Purpose:         So a timer can be calculated not based on total items to craft, but just on what is in bags
--                  So that the addon can make it's own timer based on that.
Crafting.Get_Remaining_Count_Bags = function (item_id)
    if not item_id then
        if MSA.SC.g_item_id ~= 0 then
            item_id = MSA.SC.g_item_id;
            salvage_item_id = MSA.SC.g_item_id;
        else
            item_id = salvage_item_id;
        end
    end
    local total_count = 0

    if ProfessionsFrame and ProfessionsFrame.CraftingPage.SchematicForm:IsVisible() then
        local item = ProfessionsFrame.CraftingPage.SchematicForm:GetTransaction().salvageItem;
        if not item or type(item.debugItemID) ~= "number" then
            return total_count;
        else
            item_id = item.debugItemID;
        end
    end

    if item_id == 0 then
        return total_count;
    end

    -- Let's see what's in our bags!
    for bag = 0 , NUM_BAG_SLOTS + 1 do  -- Loop through all bags + reagent bag
        for slot = 1, C_Container.GetContainerNumSlots( bag ) do
            local item_info = C_Container.GetContainerItemInfo( bag , slot )

            -- Establish the first stack size and the total amoutn
            -- We do this because I need to know if there are additional items in the bags to be stacked.
            if item_info and item_info.itemID == item_id then-- item.debugItemID then
                total_count = total_count + item_info.stackCount;
            end
        end
    end

    return total_count
end

-- Method:          Crafting.Is_More_To_Craft( int )
-- What it Does:    Returns true if there are enough reagents to continue crafting
-- Purpose:         There seems to be a common bug where crafting just stops for some reason when there is maybe only 20 or so
--                  crafts remaining. Or, even you get a resourcefulness proc and now have extra to craft at the end. This will do a
--                  quick bag check if crafting should be continued again after crafting.
Crafting.Is_More_To_Craft = function( craft_id )
    local item_id;

    if MSA.SC.g_item_id ~= 0 then
        item_id = MSA.SC.g_item_id;
        salvage_item_id = MSA.SC.g_item_id;
    else
        item_id = salvage_item_id;
    end
    if ProfessionsFrame and ProfessionsFrame.CraftingPage.SchematicForm:IsVisible() then
        local item = ProfessionsFrame.CraftingPage.SchematicForm:GetTransaction().salvageItem;
        if not item or type(item.debugItemID) ~= "number" then
            return;
        else
            item_id = item.debugItemID;
        end
    end

    local max_stack_size = C_Item.GetItemMaxStackSizeByID(item_id);
    local default_stack_min = Crafting.Get_Reagent_Count_Spell(craft_id);
    local total_count = 0;
    local first_stack_count = 0;
    local needs_to_stack = false;
    local more_to_craft = false;

    -- Just an escape in case this API fails. It shouldn't but there could be issues with long latency that could cause this to error out.
    if not max_stack_size then
        return false;
    end

    -- Let's see what's in our bags!
    for bag = 0 , NUM_BAG_SLOTS + 1 do  -- Loop through all bags + reagent bag
        for slot = 1, C_Container.GetContainerNumSlots( bag ) do
            local item_info = C_Container.GetContainerItemInfo( bag , slot )

            -- Establish the first stack size and the total amoutn
            -- We do this because I need to know if there are additional items in the bags to be stacked.
            if item_info and item_info.itemID == item_id then-- item.debugItemID then
                if first_stack_count == 0 then
                    first_stack_count = item_info.stackCount;
                end
                total_count = total_count + item_info.stackCount;
            end
        end
    end

    if first_stack_count < total_count and first_stack_count < max_stack_size then
        needs_to_stack = true
    end

    if total_count >= default_stack_min then
        more_to_craft = true
    end

    return needs_to_stack , more_to_craft
end

-- Method:          Crafting.CraftListener ( int )
-- What it Does:    Acts as an event listener to control when to trigger the reagent stacking action
-- Purpose:         Quality of life helper for mass Crafting.
Crafting.CraftListener = function ( craft_id )
    if MSA_save.non_stop and not combiningStacks then
        local remaining_casts = C_TradeSkillUI.GetRemainingRecasts()

        if ( remaining_casts and remaining_casts < 25 ) then
            Crafting.CombineStacks( nil , nil , nil , nil , craft_id );
        else
            -- I separate these so I don't pull first reagent logic if not needed
            local first_stack , bag , slot = Crafting.GetFirstReagentSizeStack()

            if first_stack then
                if first_stack < 125 then
                    Crafting.CombineStacks( nil , nil , nil , nil , craft_id );

                elseif not ProfessionsFrame or (ProfessionsFrame and not ProfessionsFrame.CraftingPage.SchematicForm:IsVisible() ) and C_TradeSkillUI.IsRecipeRepeating() then
                    -- ONLY RUN THIS LOGIC IF PROFESSION WINDOW IS NOT OPEN
                    -- There is a bug where the CraftSalvage function seems to swap stacks even if you never selected it to
                    -- This compensates that by refreshing it more frequently.

                    local default_stack_min = Crafting.Get_Reagent_Count_Spell(craft_id);
                    local stack_num_rounded = ( math.floor ( ( first_stack + (default_stack_min/2) ) / default_stack_min ) * default_stack_min )    -- For mod % check == 0
                    local mod_val = 100;
                    local item_id;
                    if MSA.SC.g_item_id > 0 then
                        item_id = MSA.SC.g_item_id;
                        salvage_item_id = MSA.SC.g_item_id;
                    else
                        item_id = salvage_item_id;
                    end

                    if item_id ~= 0 then
                        local max_stack_size = C_Item.GetItemMaxStackSizeByID ( item_id )
                        if max_stack_size and max_stack_size < 1000 then
                            if ( default_stack_min * 20 ) >= ( max_stack_size / 2 ) then
                                mod_val = math.floor( max_stack_size / 4 )
                            else
                                mod_val = math.floor ( default_stack_min * 20 )
                            end
                        end

                    end

                    if stack_num_rounded % mod_val == 0 then
                        Crafting.Refresh_Crafting( craft_id , nil , bag , slot  );
                    end
                end
            end
        end
    end
end

-- Method:          Crafting.IsMassCraftingSpell ( int )
-- What it Does:    Returns true if this is a crafting spell in the list
-- Purpose:         Really just cleaner code to wrap all these truthy checks into a single function.
Crafting.IsMassCraftingSpell = function( craft_id )

    for spells in pairs ( Crafting.Profs ) do
        if Crafting.Profs[spells][craft_id] then
            return true
        end
    end

    return false
end

-- Method:          Crafting.RepeatingListener()
-- What it Does:    Acts as an active listener for mass salvaging
-- Purpose:         so that the item_id is only recorded a single time,
--                  at the start of mass salvaging, then cleared
--                  when salvaging ends.
Crafting.RepeatingListener = function()
    if not repeat_tracking then
        record_next = true;
        repeat_tracking = true
    elseif not C_TradeSkillUI.IsRecipeRepeating() then
        repeat_tracking = false;
        record_next = false;
        salvage_item_id = 0;
        MSA.SC.g_item_id = 0;
        return;
    end

    C_Timer.After( 0.1 , Crafting.RepeatingListener )
end

-- Event listener to account for actions to know when to align conditions to begin stacking the reagents in bags.
local CraftingFrame = CreateFrame( "FRAME" , "MSA_CraftingListener" );
CraftingFrame:RegisterEvent( "TRADE_SKILL_CRAFT_BEGIN" );
CraftingFrame:RegisterEvent( "UNIT_SPELLCAST_FAILED" );
CraftingFrame:RegisterEvent( "ITEM_COUNT_CHANGED" );
CraftingFrame:SetScript( "OnEvent" , function( _ , event , craft_id , _ , failed_id )

    if event == "TRADE_SKILL_CRAFT_BEGIN" then
        if Crafting.IsMassCraftingSpell ( craft_id ) then

            if not repeat_tracking then
                Crafting.RepeatingListener();
            end

            Crafting.CraftListener(craft_id);
        end

    elseif event == "UNIT_SPELLCAST_FAILED" and Crafting.Profs and Crafting.IsMassCraftingSpell ( failed_id ) and MSA_save.non_stop and C_TradeSkillUI.GetCraftableCount(failed_id) > 0 and not combiningStacks then
        local needs_to_stack , more_to_craft = Crafting.Is_More_To_Craft(failed_id);

        -- Do we need to restack herbs and restart, or do we need to just restart
        if needs_to_stack then
            Crafting.CombineStacks( nil , nil , nil , true , failed_id );

        elseif more_to_craft then
            print("MSA - Crafting has ended prematurely. Please restart and crafting will continue nonstop" )
        end

    elseif event == "ITEM_COUNT_CHANGED" and record_next then
        salvage_item_id = craft_id;
        record_next = false;
    end

end);
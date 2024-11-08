-- For the UI Frames of Mass Salvage Assist adddon

local UI = {};
MSA.UI = UI;

-- Holds GUI frame load configuration details
UI.LoadUI = function()

    -- Checkbox to be placed on inscription window
    if not UI.MSA_checkbox then

        UI.MSA_checkbox = CreateFrame ( "CheckButton" , "MSA_checkbox" , ProfessionsFrame.CraftingPage , "InterfaceOptionsCheckButtonTemplate" )
        UI.MSA_checkbox.value = MSA_save.non_stop
        UI.MSA_checkbox:SetChecked ( UI.MSA_checkbox.value )

        -- Text to the right of checkbox
        UI.MSA_checkbox.Text = UI.MSA_checkbox:CreateFontString ( nil , "OVERLAY" , "GameFontNormal" )
        UI.MSA_checkbox.Text:SetText( "Nonstop Crafting" )
        UI.MSA_checkbox.Text:SetPoint( "LEFT" , UI.MSA_checkbox, "RIGHT" , 2 , 0 )

        -- Normalize the click area of check button to length of the text
        UI.MSA_checkbox:SetHitRectInsets ( 0 , 0 - UI.MSA_checkbox.Text:GetWidth() - 2 , 0 , 0 );

        -- Ensures this is always to the left of the CreateAllButton, accounting for width of text also
        UI.MSA_checkbox:SetPoint ( "BOTTOMLEFT" , ProfessionsFrame.CraftingPage.CreateAllButton , "TOPLEFT" , 0 , 10 )

        -- Change the setting wether enabled or not
        UI.MSA_checkbox:SetScript ( "OnClick" , function( self )
            MSA_save.non_stop = self:GetChecked()
            UI.MSA_checkbox.value = MSA_save.non_stop
        end)

        -- Tooltip
        UI.MSA_checkbox:SetScript ( "OnEnter" , function( self )
            GameTooltip:SetOwner ( self , "ANCHOR_CURSOR" );
            GameTooltip:AddLine ( "MSA Limitation: Nonstop will only work for reagents within player bags, not bank tabs." );
            GameTooltip:Show();
        end);

        UI.MSA_checkbox:SetScript ( "OnLeave" , function()
            GameTooltip:Hide()
        end)

        -- Create an event to track when the profession spell changes thus it only runs the checkbox
        -- Show or Hide when necessary
        local Checkbox_Tracker = CreateFrame ( "Frame" );
        Checkbox_Tracker:RegisterEvent ( "SPELL_DATA_LOAD_RESULT" );
        Checkbox_Tracker.craft_id = 0;
        Checkbox_Tracker:SetScript ( "OnEvent" , function( _ , _ , craft_id )
            if Checkbox_Tracker.craft_id ~= craft_id then
                if not C_TradeSkillUI.IsRecipeRepeating() then
                    Checkbox_Tracker.craft_id = craft_id;       -- Do not want to overwrite this if player  is just flipping through spells when crafting
                end
                UI.Configure_Visiblity( craft_id );
            end
        end);

    end

    if not UI.MSA_Timer_Button then
        --- TIMER BUTTON
        UI.MSA_Timer_Button = CreateFrame ( "Button" , "MSA_Timer_Button" , ProfessionsFrame.CraftingPage.SchematicForm , "UIPanelButtonTemplate" );
        UI.MSA_Timer_Button:SetSize( 100 , 20 );
        UI.MSA_Timer_Button:SetPoint( "TOPRIGHT" , ProfessionsFrame.CraftingPage.SchematicForm , "TOPRIGHT" , -5 , -35 )
        UI.MSA_Timer_Button:SetText ( "Timer" );

        UI.MSA_Timer_Button:SetScript ( "OnClick" , function()
            if UI.CT_Core_Frame:IsVisible() then
                UI.CT_Core_Frame:Hide();
            else
                UI.CT_Core_Frame:Show();
            end
        end);

        UI.MSA_Timer_Button:SetScript ( "OnEnter" , function( self )
            GameTooltip:SetOwner ( self , "ANCHOR_CURSOR" );
            GameTooltip:AddLine ( "Typing \'/msa timer\' to open/close also works." );
            GameTooltip:Show();
        end);

        UI.MSA_Timer_Button:SetScript ( "OnLeave" , function()
            GameTooltip:Hide()
        end)

    end

end

----------------------------
------ UI DEVELOPMENT ------
---------- TIMER -----------
----------------------------

-- Deploy it
UI.Deploy_Timer_UI = function()

    if not UI.CT_Core_Frame then
        -- Core frame
        UI.CT_Core_Frame = CreateFrame( "Frame" , "CT_Core_Frame" , UIParent , BackdropTemplateMixin and "BackdropTemplate" );
        UI.CT_Core_Frame:SetBackdrop ( {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background" ,
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 8,
            insets = { left = 2 , right = 2 , top = 3 , bottom = 2 }
         })
        UI.CT_Core_Frame:SetPoint ( MSA_save.pos[1] , UIParent , MSA_save.pos[2] , MSA_save.pos[3] , MSA_save.pos[4] );
        UI.CT_Core_Frame:SetSize( 320 , 110 );
        UI.CT_Core_Frame:EnableMouse ( true );
        UI.CT_Core_Frame:SetToplevel ( true );
        UI.CT_Core_Frame:SetFrameStrata("HIGH");
        UI.CT_Core_Frame:EnableMouse ( true );
        UI.CT_Core_Frame:SetMovable ( true );
        UI.CT_Core_Frame:RegisterForDrag ( "LeftButton" );
        UI.CT_Core_Frame:SetScript ( "OnDragStart" , UI.CT_Core_Frame.StartMoving )
        UI.CT_Core_Frame:SetScript ( "OnDragStop" , function( self )
            self:StopMovingOrSizing()
            local pos1 , _ , pos2 , x , y = self:GetPoint();
            MSA_save.pos = { pos1 , pos2 , x , y };
        end);
        UI.CT_Core_Frame.value = 0              -- Will be placeholder of the seconds...
        UI.CT_Core_Frame.On_Update_Timer = 0;   -- Control speed of on_update.
        UI.CT_Core_Frame.craft_id = 0;          -- Keep tabs on the craft ID
        UI.CT_Core_Frame.refresh_count = 0      -- Refresh the countdown every X crafts

        -- Keep it closed at start
        UI.CT_Core_Frame:Hide();

        UI.CT_Core_Frame:SetScript( "OnShow" , function()
            if C_TradeSkillUI.IsRecipeRepeating() then
                if #MSA.CT.timer_table < 10 and #MSA.CT.timer_table > 0 then
                    MSA.UI.CT_Core_Frame.Countdown_Text:SetText( "Calculating..." )
                elseif MSA.UI.CT_Core_Frame.value > 0 then
                    MSA.UI.CT_Core_Frame.Countdown_Text:SetText( MSA.CT.formatTime ( MSA.UI.CT_Core_Frame.value ) );
                end
            end
        end)

        -- Close Button
        UI.CT_Core_Frame.CT_CloseButton = CreateFrame( "Button" , "CT_CloseButton" , UI.CT_Core_Frame , "UIPanelCloseButton");
        UI.CT_Core_Frame.CT_CloseButton:SetPoint( "TOPRIGHT" , UI.CT_Core_Frame , "TOPRIGHT" , -4 , -4 );
        UI.CT_Core_Frame.CT_CloseButton:SetSize ( 26 , 26 );

        -- Font Strings Title and main
        UI.CT_Core_Frame.Header_Text = UI.CT_Core_Frame:CreateFontString ( nil , "OVERLAY" , "GameFontWhiteTiny" );
        UI.CT_Core_Frame.Header_Text:SetPoint ( "TOP" , UI.CT_Core_Frame, "TOP" , 0 , -12 );
        UI.CT_Core_Frame.Header_Text:SetFont( STANDARD_TEXT_FONT , 14 , "BOLD");
        UI.CT_Core_Frame.Header_Text:SetText ( "Time Remaining" );

        UI.CT_Core_Frame.Countdown_Text = UI.CT_Core_Frame:CreateFontString ( nil , "OVERLAY" , "GameFontWhite" );
        UI.CT_Core_Frame.Countdown_Text:SetPoint ( "TOP" , UI.CT_Core_Frame.Header_Text , "BOTTOM" , 0 , -5 );


        --------------------------------
        -------- TIMER SETTINGS --------
        ---------- CHECKBOXES ----------

        UI.CT_Core_Frame.Always_Show_Checkbox = CreateFrame ( "CheckButton" , "Always_Show_Checkbox" , UI.CT_Core_Frame , "InterfaceOptionsCheckButtonTemplate" )
        UI.CT_Core_Frame.Always_Show_Checkbox.value = MSA_save.always_show
        UI.CT_Core_Frame.Always_Show_Checkbox:SetChecked ( UI.CT_Core_Frame.Always_Show_Checkbox.value )

        -- Text to the right of checkbox
        UI.CT_Core_Frame.Always_Show_Checkbox.Text = UI.CT_Core_Frame.Always_Show_Checkbox:CreateFontString ( nil , "OVERLAY" , "GameFontNormal" )
        UI.CT_Core_Frame.Always_Show_Checkbox.Text:SetFont( STANDARD_TEXT_FONT , 12 , "BOLD");
        UI.CT_Core_Frame.Always_Show_Checkbox.Text:SetText( "Always Show Timer When Crafting" )
        UI.CT_Core_Frame.Always_Show_Checkbox.Text:SetPoint( "LEFT" , UI.CT_Core_Frame.Always_Show_Checkbox, "RIGHT" , 2 , 0 )

        -- Normalize the click area of check button to length of the text
        UI.CT_Core_Frame.Always_Show_Checkbox:SetHitRectInsets ( 0 , 0 - UI.CT_Core_Frame.Always_Show_Checkbox.Text:GetWidth() - 2 , 0 , 0 );

        -- Ensures this is always to the left of the CreateAllButton, accounting for width of text also
        UI.CT_Core_Frame.Always_Show_Checkbox:SetPoint ( "BOTTOMLEFT" , UI.CT_Core_Frame , "BOTTOMLEFT" , 10 , 5 )

        -- Change the setting wether enabled or not
        UI.CT_Core_Frame.Always_Show_Checkbox:SetScript ( "OnClick" , function( self )
            MSA_save.always_show = self:GetChecked()
            UI.MSA_checkbox.value = MSA_save.always_show
            if not UI.MSA_checkbox.value then
                print('If you wish to reopen the timer again, type \'/msa timer\'' )
            end
        end)

        UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox = CreateFrame ( "CheckButton" , "MSA_In_Bags_Only_Checkbox" , UI.CT_Core_Frame , "InterfaceOptionsCheckButtonTemplate" )
        UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox.value = MSA_save.count_bags_Only
        UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox:SetChecked ( UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox.value )

        -- Text to the right of checkbox
        UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox.Text = UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox:CreateFontString ( nil , "OVERLAY" , "GameFontNormal" )
        UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox.Text:SetFont( STANDARD_TEXT_FONT , 12 , "BOLD");
        UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox.Text:SetText( "Calculate using only reagents in bags." )
        UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox.Text:SetPoint( "LEFT" , UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox, "RIGHT" , 2 , 0 )

        -- Normalize the click area of check button to length of the text
        UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox:SetHitRectInsets ( 0 , 0 - UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox.Text:GetWidth() - 2 , 0 , 0 );

        -- Ensures this is always to the left of the CreateAllButton, accounting for width of text also
        UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox:SetPoint ( "BOTTOMLEFT" , UI.CT_Core_Frame.Always_Show_Checkbox , "TOPLEFT" , 0 , 0 )

        -- Change the setting wether enabled or not
        UI.CT_Core_Frame.MSA_In_Bags_Only_Checkbox:SetScript ( "OnClick" , function( self )
            MSA_save.count_bags_Only = self:GetChecked()
            UI.MSA_checkbox.value = MSA_save.count_bags_Only
            MSA.CT.Calculate_Remaining_Time();
        end)

    end

end

-----------------
--- UI LOGIC ----
-----------------

-- Method:          UI.Configure_Visiblity( nil )
-- What it Does:    Shows or hides the checkbox for mass crafting depending on prfession and spell
-- Purpose:         Only show checkbox when necessary.
UI.Configure_Visiblity = function( craft_id )
    if craft_id then
        if MSA.Crafting.Is_Salvage_Recipe( craft_id ) then
            UI.MSA_checkbox:Show()
        else
            UI.MSA_checkbox:Hide()
        end
    end
end


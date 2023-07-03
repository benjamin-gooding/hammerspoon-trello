local obj = {}
obj.__index = obj

local config = {
    chromium_browsers = {
        "com.google.chrome",
        "com.brave.browser",
        "com.microsoft.edgemac"
    }
}

local notify = {

    info = function(title, body)
        return hs.notify.new()
                 :title(title)
                 :subTitle(body)
                 :alwaysPresent(true)
                 :withdrawAfter(10)
                 :send()
    end,
    success = function(title, body)
        return hs.notify.new()
                 :title(title)
                 :subTitle(body)
                 :alwaysPresent(true)
                 :withdrawAfter(10)
                 :send()
    end,
    error = function(title, body)
        return hs.notify.new()
                 :title(title)
                 :subTitle(body)
                 :withdrawAfter(10)
                 :alwaysPresent(true)
                 :send()
    end,
}

function notify.createChain()
    local chain;
    return {
        info = function(title, body)
            if (chain ~= nil) then
                chain:withdraw();
            end ;
            chain = notify.info(title, body);
            return self;
        end,
        success = function(title, body)
            if (chain ~= nil) then
                chain:withdraw();
            end ;
            chain = notify.success(title, body);
            return self;
        end,
        error = function(title, body)
            if (chain ~= nil) then
                chain:withdraw();
            end ;
            chain = notify.error(title, body);
            return self;
        end
    }
end

local console = {
    log = function(data)
        function dump(o)
            if type(o) == 'table' then
                local s = '{ '
                for k, v in pairs(o) do
                    if type(k) ~= 'number' then
                        k = '"' .. k .. '"'
                    end
                    s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
                end
                return s .. '} '
            else
                return tostring(o)
            end
        end
        hs.console.printStyledtext(dump(data));
    end
}

local utils = {
    string = {
        trim = function(s)
            return (s:gsub("^%s*(.-)%s*$", "%1"))
        end
    },
    table = {
        merge = function(t1, t2)
            for i = 1, #t2 do
                t1[#t1 + 1] = t2[i]
            end
            return t1
        end,
        contains = function(table, value)
            for _, v in ipairs(table) do
                if v == value or (type(v) == "table" and hasValue(v, value)) then
                    return true
                end
            end
            return false
        end
    },
    envFile = {
        read = function(path)
            local file = io.open(path, "r")
            if file then
                local envTable = {}
                for line in file:lines() do
                    local key, value = line:match("^%s*([^=]+)%s*=%s*(.*)%s*$")
                    if key then
                        envTable[key] = value
                    end
                end
                file:close()
                return envTable
            end
            return nil;
        end,
        create = function(path, envData)
            local content = '';
            for key, value in pairs(envData) do
                content = content .. key .. '=' .. value .. '\n';
            end
            local file = io.open(path, "w+")
            console.log('here')
            console.log(file)

            if file then
                file:write(content)
                file:close()
                return true
            else
                return false
            end
        end,
    }
}

local env = function(key)
    local defaultNewEnvValue = 'ADD_YOURS_HERE';
    local envFilePath = hs.fs.pathToAbsolute('~/') .. '/.trellospoon';
    local envTable = utils.envFile.read(envFilePath);
    if (envTable == nil) then
        envTable = {
            ['API_TOKEN'] = defaultNewEnvValue,
            ['API_CONSUMER_KEY'] = defaultNewEnvValue,
            ['API_USER_ID'] = defaultNewEnvValue,
        };
        utils.envFile.create(envFilePath, envTable)
    end
    if (envTable[key] == nil) then
        notify.error('The property "' .. key .. '" does not exist in the "'.. envFilePath .. '"');
    end
    if (envTable[key] == defaultNewEnvValue) then
        notify.error('The property "' .. key .. '" needs to be updated in the "'.. envFilePath .. '" file');
    end
    return envTable[key];
end

local openUrl = function(url)
    local defaultBrowser = utils.string.trim(hs.execute([[
        defaults read ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure | awk -F'\"' '/http;/{print window[(NR)-1]}{window[NR]=$2}'
	]]))

    if (utils.table.contains(config.chromium_browsers, defaultBrowser)) then
        hs.osascript.applescript([[
            tell application id "]] .. defaultBrowser .. [["
                repeat with w in windows
                    set i to 1
                    repeat with t in tabs of w
                        if URL of t starts with "]] .. url .. [[" then
                            set active tab index of w to i
                            set index of w to 1
                            activate
                            return
                        end if
                        set i to i + 1
                    end repeat
                end repeat
                open location "]] .. url .. [["
            end tell
        ]])
    else
        hs.osascript.applescript([[
    	    open location "]] .. url .. [["
        ]])
    end
end

local buildUrl = function(path, queryParams)
    local url = 'https://api.trello.com/1' .. path;
    if (queryParams ~= nil) then
        url = url .. '?';
        for key, value in pairs(queryParams) do
            url = url .. '&' .. key .. '=' .. value
        end
    end
    return url;
end;

local authHeaders = function()
    return {
        ["Content-Type"] = "application/json",
        ["Authorization"] = 'OAuth oauth_consumer_key="' .. env('API_CONSUMER_KEY') .. '", oauth_token="' .. env('API_TOKEN') .. '"'
    }
end;

local selectTrelloBoard = function(callback)
    hs.http.asyncGet(buildUrl('/members/' .. env('API_USER_ID') .. '/boards?lists=open'), authHeaders(), function(status, result)
        if (status == 200) then
            local jsonResult = hs.json.decode(result);

            table.sort(jsonResult, function(a, b)
                return a.idMemberCreator == env('API_USER_ID') or b.idMemberCreator == env('API_USER_ID');
            end)

            local choices = {};
            for _, board in pairs(jsonResult) do
                table.insert(choices, {
                    text = board.name,
                    subText = board.desc,
                    board = board
                });
            end
            hs.chooser.new(function(choice)
                if (choice ~= nil) then
                    callback(choice.board)
                end
            end)
              :rows(5)
              :selectedRow(1)
              :width(30)
              :placeholderText('Select a Board...')
              :searchSubText(true)
              :choices(choices)
              :show()
        end
    end)
end

local selectTrelloBoardCard = function(board, callback)
    hs.http.asyncGet(buildUrl('/boards/' .. board.id .. '/cards'), authHeaders(), function(status, result)
        if (status == 200) then
            local jsonResult = hs.json.decode(result);
            local choices = {};
            for _, card in pairs(jsonResult) do
                if (utils.table.contains(card.idMembers, env('API_USER_ID'))) then
                    table.insert(choices, {
                        text = card.name,
                        subText = card.desc,
                        card = card
                    });
                end
            end
            hs.chooser.new(function(choice)
                if (choice ~= nil) then
                    callback(choice.card)
                end
            end)
              :rows(5)
              :selectedRow(1)
              :width(30)
              :placeholderText('Select a Card...')
              :searchSubText(true)
              :choices(choices)
              :show()
        end
    end)
end

local selectTrelloBoardList = function(board, callback)
    hs.http.asyncGet(buildUrl('/boards/' .. board.id .. '/lists'), authHeaders(), function(status, result)
        if (status == 200) then
            local jsonResult = hs.json.decode(result);
            local choices = {};
            for _, list in pairs(jsonResult) do
                table.insert(choices, {
                    text = list.name,
                    subText = list.desc,
                    list = list
                });
            end
            hs.chooser.new(function(choice)
                if (choice ~= nil) then
                    callback(choice.list)
                end
            end)
              :rows(5)
              :selectedRow(1)
              :width(30)
              :placeholderText('Select a List...')
              :searchSubText(true)
              :choices(choices)
              :show()
        end
    end)
end

local createTrelloCard = function(board, list)
    local _, userInput = hs.dialog.textPrompt('Add a new task to the"' .. list.name .. '" list on the "' .. board.name .. '" board.', '', '', 'Add', 'Cancel');
    if (userInput == '') then
        return
    end
    local queryParams = {
        ['idList'] = list.id,
        ['name'] = userInput,
        ['pos'] = 'bottom',
        ['idMembers'] = env('API_USER_ID')
    }
    hs.http.asyncPost(buildUrl('/cards'), hs.json.encode(queryParams), authHeaders(), function(status, result)
        if (status ~= 200) then
            notify.error('Failed to create the Trello Card.');
            console.log(result);
        else
            notify.success('Successfully created a card in ' .. list.name .. ' on the ' .. board.name .. ' board.');
        end
    end)
end

local moveTrelloCard = function(card, list)
    local queryParams = {
        ['idList'] = list.id,
        ['pos'] = 'top',
        ['idMembers'] = env('API_USER_ID')
    }
    hs.http.asyncPut(buildUrl('/cards/' .. card.id), hs.json.encode(queryParams), authHeaders(), function(status, result)
        if (status ~= 200) then
            notify.error('Failed to create the Trello Card.');
            console.log(result);
        else
            notify.success('Successfully moved "'.. card.name ..'" to ' .. list.name .. '.');
        end
    end)
end

function obj:init()
    local choices = {
        {
            text = 'Create a task',
            id = 'CREATE_CARD',
        },
        {
            text = 'Update task state',
            id = 'MOVE_CARD',
        },
        {
            text = 'View board in web browser',
            id = 'OPEN_BOARD_IN_BROWSER',
        },
        {
            text = 'View task in web browser',
            id = 'VIEW_CARD_IN_BROWSER',
        }
    }
    hs.hotkey.bind({ "ctrl", "cmd" }, "t", function()
        hs.chooser.new(function(choice)
            if (choice ~= nil) then
                if (choice.id == 'CREATE_CARD') then
                    selectTrelloBoard(function(board)
                        selectTrelloBoardList(board, function(list)
                            createTrelloCard(board, list)
                        end)
                    end);
                elseif (choice.id == 'MOVE_CARD') then
                    selectTrelloBoard(function(board)
                        selectTrelloBoardCard(board, function(card)
                            selectTrelloBoardList(board, function(list)
                                moveTrelloCard(card, list)
                            end)
                        end)
                    end);
                elseif (choice.id == 'OPEN_BOARD_IN_BROWSER') then
                    selectTrelloBoard(function(board)
                        openUrl(board.url);
                    end);
                elseif (choice.id == 'VIEW_CARD_IN_BROWSER') then
                    selectTrelloBoard(function(board)
                        selectTrelloBoardCard(board, function(card)
                            openUrl(card.url);
                        end)
                    end);
                end
            end
        end)
          :rows(5)
          :selectedRow(1)
          :width(30)
          :placeholderText('Select an action...')
          :searchSubText(true)
          :choices(choices)
          :show()
    end);
end

return obj

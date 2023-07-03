local obj = {}
obj.__index = obj

local config = {
    auth = {

    },
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
            for k, v in ipairs(table) do
                if v == value or (type(v) == "table" and hasValue(v, value)) then
                    return true
                end
            end
            return false
        end
    }
}

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
        ["Authorization"] = 'OAuth oauth_consumer_key="' .. config.auth.apiKey .. '", oauth_token="' .. config.auth.token .. '"'
    }
end;

local selectTrelloBoard = function(callback)
    hs.http.asyncGet(buildUrl('/members/' .. config.auth.userId .. '/boards?lists=open'), authHeaders(), function(status, result)
        if (status == 200) then
            local jsonResult = hs.json.decode(result);
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

local createTrelloCardOnBoardList = function(board, list)
    local _, userInput = hs.dialog.textPrompt('Add a new task to the"'.. list.name ..'" list on the "' .. board.name .. '" board.', '', '', 'Add', 'Cancel');
    if (userInput == '') then
        return
    end
    local queryParams = {
        ['idList'] = list.id,
        ['name'] = userInput,
        ['pos'] = 'bottom',
        ['idMembers'] = config.auth.userId
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

function obj:createTrelloTodoItem()
    selectTrelloBoard(function(board)
        selectTrelloBoardList(board, function(list)
            createTrelloCardOnBoardList(board, list)
        end)
    end);
end

function obj:init()
    console.log('-----------------------------------------------------------------------');
    hs.hotkey.bind({ "ctrl", "cmd" }, "t", obj.createTrelloTodoItem);
end

return obj

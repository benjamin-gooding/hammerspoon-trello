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
    local url = 'https://api.trello.com/'.. path ..'?key='.. config.auth.apiKey ..'&token='.. config.auth.token;
    for key, value in pairs(queryParams) do
        url = url .. '&' .. key ..'='..value
    end
    return url;
end;

local selectTrelloBoard = function(callback)
    hs.http.asyncGet(buildUrl('1/members/'.. config.auth.userId ..'/boards', {lists = 'open'}), {}, function(status, result)
        if(status == 200) then
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
              :placeholderText('Select the trello board you want to create a card on')
              :searchSubText(true)
              :choices(choices)
              :show()
        end
    end)
end

local createNewTaskOnBoard = function(board)
    console.log(board);
end

function obj:createTrelloTodoItem()
    selectTrelloBoard(createNewTaskOnBoard);
end

function obj:init()
    console.log('-----------------------------------------------------------------------');
    hs.hotkey.bind({"ctrl", "cmd"}, "t", obj.createTrelloTodoItem);
end

return obj

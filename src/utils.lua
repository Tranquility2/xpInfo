local addonName, addonTable = ...

local utils = {}

--- Formats a number by adding commas as thousands separators.
--- @param number number The number to format.
--- @return string The formatted number as a string.
function utils.FormatLargeNumber(number)
    if not number then return "0" end
    local formatted = tostring(math.floor(number))
    local k = 1
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then
            break
        end
    end
    return formatted
end

--- Formats time in hours into a readable string (e.g., "1 day, 5 hours").
--- @param hours number The total hours to format.
--- @return string The formatted time string.
function utils.FormatTimeEstimate(hours)
    if not hours or hours <= 0 then
        return "N/A"
    end
    
    local days = math.floor(hours / 24)
    local remainingHours = math.floor(hours % 24)
    local minutes = math.floor((hours % 1) * 60)
    
    local parts = {}
    
    if days > 0 then
        table.insert(parts, days .. (days == 1 and " day" or " days"))
    end
    
    if remainingHours > 0 then
        table.insert(parts, remainingHours .. (remainingHours == 1 and " hour" or " hours"))
    end
    
    if minutes > 0 and days == 0 then  -- Only show minutes if less than a day
        table.insert(parts, minutes .. (minutes == 1 and " minute" or " minutes"))
    end
    
    if #parts == 0 then
        return "Less than 1 minute"
    end
    
    return table.concat(parts, ", ")
end

addonTable.utils = utils

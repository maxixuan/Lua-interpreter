-- Lua解释器词法分析器模块
-- 本模块负责将Lua源代码文本转换为标记(tokens)序列，是Lua解释器的第一步。
-- 词法分析器识别源代码中的关键字、标识符、运算符、常量等基本语法元素，
-- 为后续的语法分析提供结构化的输入。

local lexer = {}

-- 关键字定义
-- Lua语言的保留关键字列表，用于在解析标识符时判断是否为关键字
local keywords = {
    ["and"] = true,
    ["break"] = true,
    ["do"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["end"] = true,
    ["false"] = true,
    ["for"] = true,
    ["function"] = true,
    ["if"] = true,
    ["in"] = true,
    ["local"] = true,
    ["nil"] = true,
    ["not"] = true,
    ["or"] = true,
    ["repeat"] = true,
    ["return"] = true,
    ["then"] = true,
    ["true"] = true,
    ["until"] = true,
    ["while"] = true
}

-- 创建新的词法分析器实例
-- @param code 要分析的Lua源代码字符串
-- @return 返回配置好的词法分析器实例
function lexer.new(code)
    local self = {
        code = code,        -- 源代码字符串
        position = 1,       -- 当前解析位置
        line = 1,           -- 当前行号
        column = 1          -- 当前列号
    }
    
    -- 跳过空白字符
    -- 处理空格、制表符、回车和换行符等空白字符
    function self:skipWhitespace()
        while self.position <= #self.code do
            local char = self.code:sub(self.position, self.position)
            if char == ' ' or char == '\t' or char == '\r' then
                self.position = self.position + 1
                self.column = self.column + 1
            elseif char == '\n' then
                self.position = self.position + 1
                self.line = self.line + 1
                self.column = 1
            else
                break
            end
        end
    end
    
    -- 跳过注释
    -- 处理Lua的单行注释（--开头的内容）
    -- @return 如果跳过了注释返回true，否则返回false
    function self:skipComments()
        if self.code:sub(self.position, self.position + 1) == "--" then
            self.position = self.position + 2
            self.column = self.column + 2
            
            -- 单行注释
            while self.position <= #self.code and self.code:sub(self.position, self.position) ~= "\n" do
                self.position = self.position + 1
                self.column = self.column + 1
            end
            
            if self.position <= #self.code then
                self:skipWhitespace()
                return true
            end
        end
        return false
    end
    
    -- 获取下一个字符但不消费
    -- 预览当前位置的字符而不前进指针
    -- @return 当前位置的字符
    function self:peekChar()
        return self.code:sub(self.position, self.position)
    end
    
    -- 消费当前字符并返回
    -- 前进到下一个位置并返回当前字符
    -- @return 消费的字符
    function self:nextChar()
        local char = self:peekChar()
        self.position = self.position + 1
        self.column = self.column + 1
        return char
    end
    
    -- 解析标识符或关键字
    -- 识别变量名、函数名等标识符，以及判断是否为关键字
    -- @return 标识符或关键字token，或nil（如果当前不是标识符）
    function self:parseIdentifier()
        local start = self.position
        local char = self:peekChar()
        
        -- 标识符必须以字母或下划线开头
        if not (char:match("[a-zA-Z]") or char == "_") then
            return nil
        end
        
        -- 继续解析字母、数字或下划线
        while self.position <= #self.code do
            char = self:peekChar()
            if not (char:match("[a-zA-Z0-9]") or char == "_") then
                break
            end
            self.position = self.position + 1
            self.column = self.column + 1
        end
        
        local value = self.code:sub(start, self.position - 1)
        
        -- 检查是否是关键字
        if keywords[value] then
            return { type = "keyword", value = value, line = self.line, column = self.column - #value }
        end
        
        return { type = "identifier", value = value, line = self.line, column = self.column - #value }
    end
    
    -- 解析数字
    -- 处理整数、小数和科学计数法表示的数值
    -- @return 数字token，或nil（如果当前不是数字）
    function self:parseNumber()
        local start = self.position
        local hasDecimal = false
        
        -- 解析整数部分
        while self.position <= #self.code and self:peekChar():match("[0-9]") do
            self.position = self.position + 1
            self.column = self.column + 1
        end
        
        -- 解析小数部分
        if self:peekChar() == "." then
            hasDecimal = true
            self.position = self.position + 1
            self.column = self.column + 1
            
            while self.position <= #self.code and self:peekChar():match("[0-9]") do
                self.position = self.position + 1
                self.column = self.column + 1
            end
        end
        
        -- 解析科学计数法部分
        if self:peekChar():match("[eE]") then
            hasDecimal = true
            self.position = self.position + 1
            self.column = self.column + 1
            
            if self:peekChar():match("[+-]") then
                self.position = self.position + 1
                self.column = self.column + 1
            end
            
            while self.position <= #self.code and self:peekChar():match("[0-9]") do
                self.position = self.position + 1
                self.column = self.column + 1
            end
        end
        
        local value = self.code:sub(start, self.position - 1)
        if value == "." then
            -- 只是一个点，不是数字
            self.position = start
            self.column = self.column - 1
            return nil
        end
        
        local num_value
        
        -- 尝试直接将字符串转换为数值（Lua会自动处理）
        if value:match("^%-?%d+$") then
            -- 整数
            num_value = math.tointeger(value)
        elseif value:match("^%-?%d*%.%d+$") or value:match("^%-?%d+[eE][%+%-]?%d+$") then
            -- 小数或科学计数法
            num_value = math.tofixed(value)
        else
            -- 无法识别的数值格式
            num_value = 0
        end
        
        -- 再次检查类型并确保使用正确的转换函数
        local type_result = type(num_value)
        if type_result == "number" then
            num_value = math.tointeger(num_value)
        elseif type_result == "Fixed" then
            num_value = math.tofixed(num_value)
        end
        
        return { 
            type = "number", 
            value = num_value, 
            line = self.line, 
            column = self.column - #value 
        }
    end
    
    -- 解析字符串
    -- 处理单引号和双引号字符串，支持转义字符
    -- @return 字符串token，或错误token（如果字符串未闭合）
    function self:parseString()
        local quote = self:nextChar()  -- 消耗引号
        local start = self.position
        local value = ""
        
        while self.position <= #self.code do
            local char = self:nextChar()
            
            if char == "\\" then  -- 转义字符
                local nextChar = self:nextChar()
                if nextChar == "\"" or nextChar == "'" or nextChar == "\\" then
                    value = value .. nextChar
                elseif nextChar == "a" then
                    value = value .. "\a" -- 响铃
                elseif nextChar == "b" then
                    value = value .. "\b" -- 退格
                elseif nextChar == "f" then
                    value = value .. "\f" -- 换页
                elseif nextChar == "n" then
                    value = value .. "\n" -- 换行
                elseif nextChar == "r" then
                    value = value .. "\r" -- 回车
                elseif nextChar == "t" then
                    value = value .. "\t" -- 制表符
                elseif nextChar == "v" then
                    value = value .. "\v" -- 垂直制表符
                elseif nextChar == "" then
                    value = value .. "\0" -- 空字符
                else
                    value = value .. "\\" .. nextChar
                end
            elseif char == quote then
                return { type = "string", value = value, line = self.line, column = self.column - #value - 1 }
            elseif char == "\n" then
                -- 字符串未闭合
                return { type = "error", value = "Unclosed string", line = self.line, column = self.column - 1 }
            else
                value = value .. char
            end
        end
        
        return { type = "error", value = "Unclosed string", line = self.line, column = self.column - 1 }
    end
    
    -- 获取下一个标记
    -- 词法分析的主要入口，识别并返回源代码中的下一个token
    -- @return 识别的token对象，包含类型、值和位置信息
    function self:nextToken()
        -- 跳过空白和注释
        while true do
            self:skipWhitespace()
            if not self:skipComments() then
                break
            end
        end
        
        if self.position > #self.code then
            return { type = "EOF", value = nil, line = self.line, column = self.column }
        end
        
        local char = self:peekChar()
        
        -- 解析标识符或关键字
        if char:match("[a-zA-Z_]") then
            return self:parseIdentifier()
        end
        
        -- 解析数字
        if char:match("[0-9]") or (char == "." and self.code:sub(self.position + 1, self.position + 1):match("[0-9]")) then
            return self:parseNumber()
        end
        
        -- 解析字符串
        if char == '"' or char == "'" then
            return self:parseString()
        end
        
        -- 解析操作符和标点符号
        if char == "=" then
            self:nextChar()
            if self:peekChar() == "=" then
                self:nextChar()
                return { type = "operator", value = "==", line = self.line, column = self.column - 2 }
            end
            return { type = "operator", value = "=", line = self.line, column = self.column - 1 }
        end
        
        if char == "~" then
            self:nextChar()
            if self:peekChar() == "=" then
                self:nextChar()
                return { type = "operator", value = "~", line = self.line, column = self.column - 2 }
            end
            return { type = "operator", value = "~", line = self.line, column = self.column - 1 }
        end
        
        if char == ":" then
            self:nextChar()
            if self:peekChar() == ":" then
                self:nextChar()
                return { type = "operator", value = "::", line = self.line, column = self.column - 2 }
            end
            return { type = "operator", value = ":", line = self.line, column = self.column - 1 }
        end
        
        if char == "." then
            self:nextChar()
            if self:peekChar() == "." then
                self:nextChar()
                if self:peekChar() == "." then
                    self:nextChar()
                    return { type = "operator", value = "...", line = self.line, column = self.column - 3 }
                end
                return { type = "operator", value = "..", line = self.line, column = self.column - 2 }
            end
            return { type = "operator", value = ".", line = self.line, column = self.column - 1 }
        end
        
        if char == "+" or char == "-" then
            self:nextChar()
            return { type = "operator", value = char, line = self.line, column = self.column - 1 }
        end
        
        if char == "*" or char == "/" or char == "%" then
            self:nextChar()
            return { type = "operator", value = char, line = self.line, column = self.column - 1 }
        end
        
        if char == "<" or char == ">" then
            self:nextChar()
            if self:peekChar() == "=" then
                self:nextChar()
                return { type = "operator", value = char .. "=", line = self.line, column = self.column - 2 }
            end
            return { type = "operator", value = char, line = self.line, column = self.column - 1 }
        end
        
        if char == "(" or char == ")" or char == "{" or char == "}" or char == "[" or char == "]" then
            self:nextChar()
            return { type = "punctuator", value = char, line = self.line, column = self.column - 1 }
        end
        
        if char == "," or char == ";" then
            self:nextChar()
            return { type = "punctuator", value = char, line = self.line, column = self.column - 1 }
        end
        
        -- 未知字符
        self:nextChar()
        return { type = "error", value = "Unknown character: " .. char, line = self.line, column = self.column - 1 }
    end
    
    -- 获取所有标记
    -- 遍历整个源代码并收集所有的tokens，直到EOF
    -- @return 所有识别的token列表
    function self:getAllTokens()
        local tokens = {}
        while true do
            local token = self:nextToken()
            table.insert(tokens, token)
            if token.type == "EOF" then
                break
            end
        end
        return tokens
    end
    
    return self
end

return lexer
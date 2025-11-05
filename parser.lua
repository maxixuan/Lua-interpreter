-- Lua解释器语法分析器模块
-- 本模块负责将词法分析器生成的token流转换为抽象语法树(AST)，
-- 实现了递归下降解析算法，遵循Lua语言的语法规则进行语法分析。
-- 支持表达式、语句、函数定义等Lua语言核心结构的解析。

local parser = {}

-- 创建新的语法分析器实例
-- @param lexer 词法分析器实例，提供nextToken方法
-- @return 返回配置好的语法分析器实例
function parser.new(lexer)
    local self = {
        lexer = lexer,  -- 词法分析器实例
        currentToken = nil,  -- 当前处理的token
        nextToken = nil  -- 下一个待处理的token
    }
    
    -- 前进到下一个标记
    -- 更新currentToken和nextToken指针
    function self:advance()
        self.currentToken = self.nextToken or self.lexer:nextToken()
        self.nextToken = self.lexer:nextToken()
    end
    
    -- 期望当前标记为指定类型，如果是则前进，否则报错
    -- @param type 期望的token类型
    -- @param value 可选的期望token值
    -- @return 返回匹配的token
    function self:expect(type, value)
        if self.currentToken.type ~= type or (value and self.currentToken.value ~= value) then
            error(string.format("Syntax error at line %d, column %d: Expected %s %s but got %s %s",
                self.currentToken.line,
                self.currentToken.column,
                type,
                value or "",
                self.currentToken.type,
                self.currentToken.value or ""))
        end
        local token = self.currentToken
        self:advance()
        return token
    end
    
    -- 检查当前标记类型
    -- @param type 要检查的token类型
    -- @param value 可选的token值
    -- @return 如果匹配返回true，否则返回false
    function self:isCurrent(type, value)
        return self.currentToken.type == type and (not value or self.currentToken.value == value)
    end
    
    -- 检查下一个标记类型
    -- @param type 要检查的token类型
    -- @param value 可选的token值
    -- @return 如果匹配返回true，否则返回false
    function self:isNext(type, value)
        return self.nextToken.type == type and (not value or self.nextToken.value == value)
    end
    
    -- 解析表达式
    -- 表达式解析的入口点，从最低优先级操作符开始
    -- @return 返回解析后的表达式节点
    function self:parseExpression()
        return self:parseOrExpression()
    end
    
    -- 解析或表达式 (or)
    -- 处理逻辑或操作，优先级最低
    -- @return 返回解析后的表达式节点
    function self:parseOrExpression()
        local left = self:parseAndExpression()
        
        while self:isCurrent("keyword", "or") do
            self:advance()
            local right = self:parseAndExpression()
            left = { type = "binary_op", operator = "or", left = left, right = right }
        end
        
        return left
    end
    
    -- 解析与表达式 (and)
    -- 处理逻辑与操作，优先级高于或操作
    -- @return 返回解析后的表达式节点
    function self:parseAndExpression()
        local left = self:parseRelationalExpression()
        
        while self:isCurrent("keyword", "and") do
            self:advance()
            local right = self:parseRelationalExpression()
            left = { type = "binary_op", operator = "and", left = left, right = right }
        end
        
        return left
    end
    
    -- 解析关系表达式
    -- 处理比较运算符如 ==, ~=, <, >, <=, >=
    -- @return 返回解析后的表达式节点
    function self:parseRelationalExpression()
        local left = self:parseAdditiveExpression()
        
        local operators = {
            ["=="] = true,
            ["~"] = true,
            ["<"] = true,
            [">"] = true,
            ["<="] = true,
            [">="] = true
        }
        
        while self:isCurrent("operator") and operators[self.currentToken.value] do
            local op = self.currentToken.value
            self:advance()
            local right = self:parseAdditiveExpression()
            left = { type = "binary_op", operator = op, left = left, right = right }
        end
        
        return left
    end
    
    -- 解析加法表达式 (+, -)
    -- 处理加法和减法操作
    -- @return 返回解析后的表达式节点
    function self:parseAdditiveExpression()
        local left = self:parseMultiplicativeExpression()
        
        while self:isCurrent("operator", "+") or self:isCurrent("operator", "-") do
            local op = self.currentToken.value
            self:advance()
            local right = self:parseMultiplicativeExpression()
            left = { type = "binary_op", operator = op, left = left, right = right }
        end
        
        return left
    end
    
    -- 解析乘法表达式 (*, /, %)
    -- 处理乘法、除法和取模操作
    -- @return 返回解析后的表达式节点
    function self:parseMultiplicativeExpression()
        local left = self:parseUnaryExpression()
        
        while self:isCurrent("operator", "*") or self:isCurrent("operator", "/") or self:isCurrent("operator", "%") do
            local op = self.currentToken.value
            self:advance()
            local right = self:parseUnaryExpression()
            left = { type = "binary_op", operator = op, left = left, right = right }
        end
        
        return left
    end
    
    -- 解析一元表达式 (not, #, -)
    -- 处理一元操作符，优先级较高
    -- @return 返回解析后的表达式节点
    function self:parseUnaryExpression()
        if self:isCurrent("keyword", "not") or self:isCurrent("operator", "-") or self:isCurrent("operator", "~") then
            local op = self.currentToken.value
            self:advance()
            return { type = "unary_op", operator = op, operand = self:parseUnaryExpression() }
        elseif self:isCurrent("operator", "#") then
            self:advance()
            return { type = "unary_op", operator = "#", operand = self:parseUnaryExpression() }
        end
        
        return self:parsePrimaryExpression()
    end
    
    -- 解析基本表达式
    -- 处理常量、标识符、函数定义、表构造等基本表达式
    -- @return 返回解析后的表达式节点
    function self:parsePrimaryExpression()
        if self:isCurrent("number") then
            local value = self.currentToken.value
            self:advance()
            return { type = "number", value = value }
        elseif self:isCurrent("string") then
            local value = self.currentToken.value
            self:advance()
            return { type = "string", value = value }
        elseif self:isCurrent("keyword", "true") then
            self:advance()
            return { type = "boolean", value = true }
        elseif self:isCurrent("keyword", "false") then
            self:advance()
            return { type = "boolean", value = false }
        elseif self:isCurrent("keyword", "nil") then
            self:advance()
            return { type = "nil" }
        elseif self:isCurrent("keyword", "function") then
            -- 解析匿名函数
            return self:parseFunctionDefinition()
        elseif self:isCurrent("punctuator", "(") then
            self:advance()
            local expr = self:parseExpression()
            self:expect("punctuator", ")")
            return expr
        elseif self:isCurrent("punctuator", "{") then
            return self:parseTableConstructor()
        elseif self:isCurrent("identifier") then
            return self:parseVariableExpression()
        end
        
        error(string.format("Syntax error at line %d, column %d: Unexpected token %s %s",
            self.currentToken.line,
            self.currentToken.column,
            self.currentToken.type,
            self.currentToken.value or ""))
    end
    
    -- 解析变量表达式
    -- 处理标识符及其后续操作（函数调用、索引访问等）
    -- @return 返回解析后的表达式节点
    function self:parseVariableExpression()
        local name = self.currentToken.value
        self:advance()
        
        -- 函数调用或方法调用
        if self:isCurrent("punctuator", "(") then
            return self:parseFunctionCall(name)
        elseif self:isCurrent("punctuator", "[") then
            return self:parseIndexExpression(name)
        elseif self:isCurrent("operator", ".") then
            return self:parseMemberExpression(name)
        end
        
        return { type = "identifier", name = name }
    end
    
    -- 解析函数调用
    -- 处理函数调用表达式，包括普通调用和链式调用
    -- @param prefix 函数调用的前缀（标识符或其他表达式）
    -- @return 返回解析后的函数调用节点
    function self:parseFunctionCall(prefix)
        self:expect("punctuator", "(")
        local args = {}
        
        if not self:isCurrent("punctuator", ")") then
            args[1] = self:parseExpression()
            
            while self:isCurrent("punctuator", ",") do
                self:advance()
                table.insert(args, self:parseExpression())
            end
        end
        
        self:expect("punctuator", ")")
        
        -- 检查是否有链式调用
        if self:isCurrent("punctuator", "(") then
            return self:parseFunctionCall({ type = "function_call", prefix = prefix, arguments = args })
        elseif self:isCurrent("punctuator", "[") then
            return self:parseIndexExpression({ type = "function_call", prefix = prefix, arguments = args })
        elseif self:isCurrent("operator", ".") then
            return self:parseMemberExpression({ type = "function_call", prefix = prefix, arguments = args })
        end
        
        return { type = "function_call", prefix = prefix, arguments = args }
    end
    
    -- 解析索引表达式
    -- 处理表的索引访问，如table[index]
    -- @param prefix 索引表达式的前缀（标识符或其他表达式）
    -- @return 返回解析后的索引表达式节点
    function self:parseIndexExpression(prefix)
        self:expect("punctuator", "[")
        local index = self:parseExpression()
        self:expect("punctuator", "]")
        
        -- 检查是否有链式调用
        if self:isCurrent("punctuator", "(") then
            return self:parseFunctionCall({ type = "index", prefix = prefix, index = index })
        elseif self:isCurrent("punctuator", "[") then
            return self:parseIndexExpression({ type = "index", prefix = prefix, index = index })
        elseif self:isCurrent("operator", ".") then
            return self:parseMemberExpression({ type = "index", prefix = prefix, index = index })
        end
        
        return { type = "index", prefix = prefix, index = index }
    end
    
    -- 解析成员表达式
    -- 处理表的成员访问，如table.member
    -- @param prefix 成员表达式的前缀（标识符或其他表达式）
    -- @return 返回解析后的成员表达式节点
    function self:parseMemberExpression(prefix)
        self:expect("operator", ".")
        local member_token = self:expect("identifier")
        local member = member_token.value
        
        -- 检查是否有链式调用
        if self:isCurrent("punctuator", "(") then
            return self:parseFunctionCall({ type = "member", prefix = prefix, member = member })
        elseif self:isCurrent("punctuator", "[") then
            return self:parseIndexExpression({ type = "member", prefix = prefix, member = member })
        elseif self:isCurrent("operator", ".") then
            return self:parseMemberExpression({ type = "member", prefix = prefix, member = member })
        end
        
        return { type = "member", prefix = prefix, member = member }
    end
    
    -- 解析表构造器
    -- 处理表创建表达式，如{key1=value1, [key2]=value2, value3}
    -- @return 返回解析后的表构造器节点
    function self:parseTableConstructor()
        self:expect("punctuator", "{")
        local fields = {}
        
        while not self:isCurrent("punctuator", "}") do
            -- 检查是否是键值对
            if self:isNext("operator", "=") then
                local key = self.currentToken.value
                self:advance()
                self:expect("operator", "=")
                local value = self:parseExpression()
                table.insert(fields, { type = "field", key = key, value = value })
            -- 检查是否是索引表达式
            elseif self:isCurrent("punctuator", "[") then
                self:expect("punctuator", "[")
                local key = self:parseExpression()
                self:expect("punctuator", "]")
                self:expect("operator", "=")
                local value = self:parseExpression()
                table.insert(fields, { type = "field", key = key, value = value })
            -- 默认索引
            else
                local value = self:parseExpression()
                table.insert(fields, { type = "field", value = value })
            end
            
            if not self:isCurrent("punctuator", "}") then
                self:expect("punctuator", ",")
            end
        end
        
        self:expect("punctuator", "}")
        return { type = "table_constructor", fields = fields }
    end
    
    -- 解析语句
    -- 根据token类型分发到不同的语句解析函数
    -- @return 返回解析后的语句节点
    function self:parseStatement()
        -- 检查是否到达文件末尾
        if self:isCurrent("EOF") then
            return nil
        end
        
        -- 解析局部变量声明
        if self:isCurrent("keyword", "local") then
            return self:parseLocalStatement()
        -- if语句
        elseif self:isCurrent("keyword", "if") then
            return self:parseIfStatement()
        -- while语句
        elseif self:isCurrent("keyword", "while") then
            return self:parseWhileStatement()
        -- for语句
        elseif self:isCurrent("keyword", "for") then
            return self:parseForStatement()
        -- repeat语句
        elseif self:isCurrent("keyword", "repeat") then
            return self:parseRepeatStatement()
        -- 函数定义
        elseif self:isCurrent("keyword", "function") then
            return self:parseFunctionDefinition()
        -- return语句
        elseif self:isCurrent("keyword", "return") then
            return self:parseReturnStatement()
        -- break语句
        elseif self:isCurrent("keyword", "break") then
            self:advance()
            return { type = "break" }
        -- 表达式语句或赋值语句
        else
            -- 尝试解析表达式作为语句
            local expr = self:parseExpression()
            if expr then
                -- 检查是否是赋值语句
                if self:isCurrent("operator", "=") then
                    self:advance()
                    local right = self:parseExpression()
                    -- 跳过可选的分号
                    if self:isCurrent("punctuator", ";") then
                        self:advance()
                    end
                    return { type = "assignment", left = expr, right = right }
                end
                -- 跳过可选的分号
                if self:isCurrent("punctuator", ";") then
                    self:advance()
                end
                return { type = "expression_statement", expression = expr }
            end
        end
        
        return nil
    end
    
    -- 解析局部变量声明
    -- 处理local变量定义，支持多个变量同时声明和初始化
    -- @return 返回解析后的局部变量声明节点
    function self:parseLocalStatement()
        self:advance()
        
        -- 检查是否是局部函数
        if self:isCurrent("keyword", "function") then
            return self:parseLocalFunction()
        end
        
        local names = { self.currentToken.value }
        self:advance()
        
        while self:isCurrent("punctuator", ",") do
            self:advance()
            table.insert(names, self.currentToken.value)
            self:advance()
        end
        
        local values = {}
        if self:isCurrent("operator", "=") then
            self:advance()
            values[1] = self:parseExpression()
            
            while self:isCurrent("punctuator", ",") do
                self:advance()
                table.insert(values, self:parseExpression())
            end
        end
        
        return { type = "local_declaration", names = names, values = values }
    end
    
    -- 解析赋值语句
    -- 处理变量赋值操作
    -- @return 返回解析后的赋值语句节点
    function self:parseAssignmentStatement()
        -- 先保存当前位置，以便在不是赋值时回退
        
        -- 尝试解析标识符作为目标
        if not self:isCurrent("identifier") and 
           not self:isCurrent("punctuator", "(") and 
           not self:isCurrent("punctuator", "{") then
            return nil
        end
        
        -- 先尝试解析表达式
        local firstExpr = self:parseExpression()
        
        -- 检查是否有赋值操作符
        if not self:isCurrent("operator", "=") then
            -- 这不是赋值，而是普通表达式语句
            return { type = "expression_statement", expression = firstExpr }
        end
        
        self:advance()  -- 跳过 '='
        
        -- 解析右侧表达式
        local rightExpr = self:parseExpression()
        if not rightExpr then
            error("Expected expression after assignment operator")
        end
        
        return { type = "assignment", left = firstExpr, right = rightExpr }
    end
    
    -- 解析if语句
    -- 处理条件判断和分支执行，支持elseif和else子句
    -- @return 返回解析后的if语句节点
    function self:parseIfStatement()
        self:advance()
        local condition = self:parseExpression()
        self:expect("keyword", "then")
        local body = self:parseBlock()
        
        local elseifs = {}
        while self:isCurrent("keyword", "elseif") do
            self:advance()
            local elseifCondition = self:parseExpression()
            self:expect("keyword", "then")
            local elseifBody = self:parseBlock()
            table.insert(elseifs, { condition = elseifCondition, body = elseifBody })
        end
        
        local elseBody = nil
        if self:isCurrent("keyword", "else") then
            self:advance()
            elseBody = self:parseBlock()
        end
        
        self:expect("keyword", "end")
        
        return { 
            type = "if_statement", 
            condition = condition, 
            body = body, 
            elseifs = elseifs,
            else_body = elseBody 
        }
    end
    
    -- 解析while语句
    -- 处理while循环结构
    -- @return 返回解析后的while语句节点
    function self:parseWhileStatement()
        self:advance()
        local condition = self:parseExpression()
        self:expect("keyword", "do")
        local body = self:parseBlock()
        self:expect("keyword", "end")
        
        return { type = "while_statement", condition = condition, body = body }
    end
    
    -- 解析for语句 (简化版)
    -- 处理数值for循环，支持可选的步长参数
    -- @return 返回解析后的for语句节点
    function self:parseForStatement()
        self:advance()
        local varName = self.currentToken.value
        self:advance()
        self:expect("operator", "=")
        
        local start = self:parseExpression()
        self:expect("punctuator", ",")
        local finish = self:parseExpression()
        
        local step = nil
        if self:isCurrent("punctuator", ",") then
            self:advance()
            step = self:parseExpression()
        end
        
        self:expect("keyword", "do")
        local body = self:parseBlock()
        self:expect("keyword", "end")
        
        return { 
            type = "for_statement", 
            variable = varName, 
            start = start, 
            finish = finish, 
            step = step, 
            body = body 
        }
    end
    
    -- 解析repeat语句
    -- 处理repeat-until循环结构
    -- @return 返回解析后的repeat语句节点
    function self:parseRepeatStatement()
        self:advance()
        local body = self:parseBlock()
        self:expect("keyword", "until")
        local condition = self:parseExpression()
        
        return { type = "repeat_statement", body = body, condition = condition }
    end
    
    -- 解析函数定义
    -- 处理命名函数和匿名函数定义，支持冒号语法的方法定义
    -- @return 返回解析后的函数定义节点
    function self:parseFunctionDefinition()
        if not self:isCurrent("keyword", "function") then
            return nil
        end
        
        self:advance()  -- 跳过 'function'
        
        -- 函数名
        local name
        if self:isCurrent("identifier") then
            name = self.currentToken.value
            self:advance()
            
            -- 可选的冒号语法
            if self:isCurrent("operator", ":") then
                self:advance()
                if self:isCurrent("identifier") then
                    name = name .. ":" .. self.currentToken.value
                    self:advance()
                else
                    error("Expected identifier after colon in function definition")
                end
            end
        else
            -- 匿名函数
            name = nil
        end
        
        -- 解析参数列表
        self:expect("punctuator", "(")
        local params = {}
        
        if not self:isCurrent("punctuator", ")") then
            params[1] = self.currentToken.value
            self:advance()
            
            while self:isCurrent("punctuator", ",") do
                self:advance()
                table.insert(params, self.currentToken.value)
                self:advance()
            end
        end
        
        self:expect("punctuator", ")")
        local body = self:parseBlock()
        self:expect("keyword", "end")
        
        return { type = "function_definition", name = name, parameters = params, body = body }
    end
    
    -- 解析局部函数
    -- 处理local function定义
    -- @return 返回解析后的局部函数节点
    function self:parseLocalFunction()
        self:advance()
        local name = self.currentToken.value
        self:advance()
        
        self:expect("punctuator", "(")
        local params = {}
        
        if not self:isCurrent("punctuator", ")") then
            params[1] = self.currentToken.value
            self:advance()
            
            while self:isCurrent("punctuator", ",") do
                self:advance()
                table.insert(params, self.currentToken.value)
                self:advance()
            end
        end
        
        self:expect("punctuator", ")")
        local body = self:parseBlock()
        self:expect("keyword", "end")
        
        return { type = "local_function", name = name, parameters = params, body = body }
    end
    
    -- 解析return语句
    -- 处理函数返回语句，支持多个返回值
    -- @return 返回解析后的return语句节点
    function self:parseReturnStatement()
        self:advance()
        
        local expressions = {}
        if not self:isCurrent("keyword", "end") and not self:isCurrent("keyword", "elseif") and not self:isCurrent("keyword", "else") then
            expressions[1] = self:parseExpression()
            
            while self:isCurrent("punctuator", ",") do
                self:advance()
                table.insert(expressions, self:parseExpression())
            end
        end
        
        return { type = "return_statement", expressions = expressions }
    end
    
    -- 解析代码块
    -- 解析连续的语句序列，直到遇到块结束标记
    -- @return 返回解析后的代码块节点
    function self:parseBlock()
        local statements = {}
        
        -- 解析所有语句，直到遇到块结束标记或文件结束
        while not self:isCurrent("keyword", "end") and 
              not self:isCurrent("keyword", "elseif") and 
              not self:isCurrent("keyword", "else") and 
              not self:isCurrent("keyword", "until") and
              not self:isCurrent("EOF") do
            -- 尝试解析语句
            local statement = self:parseStatement()
            
            if statement then
                table.insert(statements, statement)
            else
                -- 如果没有识别出语句，跳过无法识别的标记
                if not self:isCurrent("keyword", "end") and 
                   not self:isCurrent("keyword", "elseif") and 
                   not self:isCurrent("keyword", "else") and 
                   not self:isCurrent("keyword", "until") and
                   not self:isCurrent("EOF") then
                    self:advance()
                end
            end
        end
        
        return { type = "block", statements = statements }
    end
    
    -- 解析整个程序
    -- 解析完整的Lua程序，处理顶层语句
    -- @return 返回解析后的程序节点
    function self:parseProgram()
        self:advance()  -- 获取第一个标记
        local statements = {}
        
        -- 解析所有语句直到文件结束
        while not self:isCurrent("EOF") do
            -- 检查是否是分号，如果是则跳过
            if self:isCurrent("punctuator", ";") then
                self:advance()
                goto continue
            end
            
            -- 尝试各种语句类型
            local statement = self:parseStatement()
            
            if statement then
                table.insert(statements, statement)
                
                -- 检查语句后是否有分号，如果有则跳过
                while self:isCurrent("punctuator", ";") do
                    self:advance()
                end
            else
                -- 如果没有识别出语句，检查是否是空白或注释
                if not self:isCurrent("EOF") then
                    -- 跳过未知标记，继续解析
                    self:advance()
                end
            end
            
            ::continue::
        end
        
        return { type = "program", block = { type = "block", statements = statements } }
    end
    
    return self
end

return parser
-- Lua解释器评估器模块
-- 本模块负责遍历和执行抽象语法树(AST)，实现Lua代码的运行时计算。
-- 提供了表达式求值、语句执行、作用域管理等核心功能，
-- 是Lua解释器的运行时核心组件。

local evaluator = {}

-- 创建新的执行器实例
-- @param ast 抽象语法树，由解析器生成的程序结构
-- @param sandbox 可选的沙盒环境表，用于提供和限制全局变量
-- @return 返回配置好的执行器实例
function evaluator.new(ast, sandbox)
    local self = {
        ast = ast,
        sandbox = sandbox or {}
    }
    
    -- 创建新的环境作用域
    -- 实现了Lua的作用域链查找机制，支持变量的局部作用域和向上查找
    -- @param parent 父作用域表，用于变量的作用域链查找
    -- @return 返回新创建的作用域表
    function self:createScope(parent)
        local scope = {}
        setmetatable(scope, {
            __index = function(t, k)
                if parent and parent[k] ~= nil then
                    return parent[k]
                elseif self.sandbox[k] ~= nil then
                    return self.sandbox[k]
                end
                return nil
            end,
            -- 实现Lua变量赋值规则的元方法
            -- 处理局部变量和非局部变量的不同赋值逻辑
            __newindex = function(t, k, v)
                -- 检查变量是否在当前作用域中已经存在（局部变量）
                if rawget(t, k) ~= nil then
                    -- 如果是当前作用域的局部变量，直接修改
                    rawset(t, k, v)
                else
                    -- 否则，检查变量是否在父作用域中存在
                    local currentParent = parent
                    while currentParent do
                        -- 检查父作用域是否直接包含该变量（不通过__index）
                        local metatable = getmetatable(currentParent)
                        if metatable and type(metatable.__getraw) == 'function' then
                            if metatable.__getraw(currentParent, k) ~= nil then
                                currentParent[k] = v
                                return
                            end
                        elseif rawget(currentParent, k) ~= nil then
                            currentParent[k] = v
                            return
                        end
                        -- 检查是否还有更高层的父作用域
                        local parentMeta = getmetatable(currentParent)
                        if parentMeta and parentMeta.__parent then
                            currentParent = parentMeta.__parent
                        else
                            break
                        end
                    end
                    
                    -- 如果变量在任何父作用域中都不存在，则将其定义为当前作用域的局部变量
                    rawset(t, k, v)
                end
            end
        })
        
        -- 为了能够检查变量是否直接存在于作用域中，添加__getraw方法
        local meta = getmetatable(scope)
        meta.__parent = parent
        meta.__getraw = function(t, k)
            return rawget(t, k)
        end
        
        return scope
    end
    
    -- 执行表达式
    -- 根据表达式类型分发到不同的处理函数进行求值
    -- @param expr 要求值的表达式节点
    -- @param scope 当前执行的作用域
    -- @return 返回表达式求值的结果
    function self:evaluateExpression(expr, scope)
        if not expr then
            error("Expression is nil")
        end
        
        local exprType = expr.type or "nil"
        
        -- 兼容新旧两种命名方式
        if exprType == "number" or exprType == "Number" then
            return expr.value
        elseif exprType == "string" or exprType == "String" then
            return expr.value
        elseif exprType == "boolean" or exprType == "Boolean" then
            return expr.value
        elseif exprType == "nil" or exprType == "Nil" then
            return nil
        elseif exprType == "identifier" or exprType == "Identifier" then
            return scope[expr.name]
        elseif exprType == "binary_op" or exprType == "BinaryOp" or exprType == "BinaryExpression" then
            -- 修正函数调用参数，传递整个expr对象
            return self:evaluateBinaryOp(expr, scope)
        elseif exprType == "unary_op" or exprType == "UnaryOp" or exprType == "UnaryExpression" then
            return self:evaluateUnaryOp(expr, scope)
        elseif exprType == "function_call" or exprType == "FunctionCall" then
            return self:evaluateFunctionCall(expr, scope)
        elseif exprType == "function_definition" or exprType == "FunctionDefinition" then
            -- 处理匿名函数表达式
            return self:evaluateFunctionDefinition(expr, scope)
        elseif exprType == "table_constructor" or exprType == "TableConstructor" or exprType == "TableLiteral" then
            return self:evaluateTableConstructor(expr, scope)
        elseif exprType == "member" or exprType == "MemberExpression" then
            return self:evaluateMember(expr, scope)
        elseif exprType == "index" or exprType == "Index" or exprType == "IndexExpression" then
            return self:evaluateIndex(expr, scope)
        elseif exprType == "member" or exprType == "Member" or exprType == "MemberExpression" then
            return self:evaluateMember(expr, scope)
        end
        
        error("Unknown expression type: " .. tostring(exprType) .. ", value: " .. tostring(expr))
    end
    
    -- 执行二元操作
    -- 处理算术、比较、逻辑等二元运算符
    -- @param expr 二元操作表达式节点
    -- @param scope 当前执行的作用域
    -- @return 返回二元运算的结果
    function self:evaluateBinaryOp(expr, scope)
        if not expr or not scope then
            error("Invalid arguments to evaluateBinaryOp")
        end
        
        local left = self:evaluateExpression(expr.left, scope)
        local right = self:evaluateExpression(expr.right, scope)
        
        -- 增强错误处理：确保算术运算的操作数不为nil
        if (expr.operator == "+" or expr.operator == "-" or expr.operator == "*" or expr.operator == "/" or expr.operator == "%") then
            if left == nil then
                error("attempt to perform arithmetic on a nil value (left operand)")
            end
            if right == nil then
                error("attempt to perform arithmetic on a nil value (right operand)")
            end
        end
        
        if expr.operator == "+" then
            return left + right
        elseif expr.operator == "-" then
            return left - right
        elseif expr.operator == "*" then
            return left * right
        elseif expr.operator == "/" then
            if right == 0 then
                error("attempt to divide by zero")
            end
            return left / right
        elseif expr.operator == "%" then
            return left % right
        elseif expr.operator == "==" then
            return left == right
        elseif expr.operator == "~=" then
            return left ~= right
        elseif expr.operator == "<" then
            return left < right
        elseif expr.operator == ">" then
            return left > right
        elseif expr.operator == "<=" then
            return left <= right
        elseif expr.operator == ">=" then
            return left >= right
        elseif expr.operator == "and" then
            return left and right
        elseif expr.operator == "or" then
            return left or right
        elseif expr.operator == ".." then
            return tostring(left) .. tostring(right)
        end
        
        error("Unknown binary operator: " .. tostring(expr.operator))
    end
    
    -- 执行一元操作
    -- 处理负号、逻辑非、长度运算符等一元操作
    -- @param expr 一元操作表达式节点
    -- @param scope 当前执行的作用域
    -- @return 返回一元运算的结果
    function self:evaluateUnaryOp(expr, scope)
        local operand = self:evaluateExpression(expr.operand, scope)
        
        if expr.operator == "-" then
            return -operand
        elseif expr.operator == "not" then
            return not operand
        elseif expr.operator == "#" then
            if type(operand) == "string" then
                return #operand
            elseif type(operand) == "table" then
                local count = 0
                for _ in pairs(operand) do
                    count = count + 1
                end
                return count
            end
            error("Length operator only works on strings and tables")
        elseif expr.operator == "~" then
            return ~operand
        end
        
        error("Unknown unary operator: " .. expr.operator)
    end
    
    -- 执行函数调用
    -- 查找函数并执行，处理参数传递
    -- @param expr 函数调用表达式节点
    -- @param scope 当前执行的作用域
    -- @return 返回函数调用的结果
    function self:evaluateFunctionCall(expr, scope)
        local func
        if type(expr.prefix) == "string" then
            func = scope[expr.prefix]
        else
            -- 确保prefix是有效的表达式对象
            if not expr.prefix or type(expr.prefix) ~= "table" then
                error("Invalid function call prefix")
            end
            func = self:evaluateExpression(expr.prefix, scope)
        end
        
        if type(func) ~= "function" then
            error("Attempt to call a non-function value: " .. tostring(func))
        end
        
        -- 计算参数
        local args = {}
        for i, argExpr in ipairs(expr.arguments or {}) do
            args[i] = self:evaluateExpression(argExpr, scope)
        end
        
        -- 调用函数，使用table.unpack替代unpack以兼容新版本
        return func(table.unpack(args))
    end
    
    -- 执行表构造器
    -- 创建并初始化新的表对象
    -- @param expr 表构造器表达式节点
    -- @param scope 当前执行的作用域
    -- @return 返回构造的表对象
    function self:evaluateTableConstructor(expr, scope)
        local tbl = {}
        local index = 1
        
        for _, field in ipairs(expr.fields) do
            if field.key then
                -- 键值对
                local key
                if type(field.key) == "string" then
                    key = field.key
                else
                    key = self:evaluateExpression(field.key, scope)
                end
                tbl[key] = self:evaluateExpression(field.value, scope)
            else
                -- 默认索引
                tbl[index] = self:evaluateExpression(field.value, scope)
                index = index + 1
            end
        end
        
        return tbl
    end
    
    -- 执行索引表达式
    -- 处理表的索引访问操作，如table[index]
    -- @param expr 索引表达式节点
    -- @param scope 当前执行的作用域
    -- @return 返回索引访问的结果
    function self:evaluateIndex(expr, scope)
        -- 确保表达式结构有效
        if not expr then
            error("Invalid index expression: nil")
        end
        
        -- 先获取前缀表达式的值，确保在索引前检查是否为nil
        local tbl
        if type(expr.prefix) == "string" then
            -- 如果prefix是字符串，直接从scope中获取
            tbl = scope[expr.prefix]
        elseif type(expr.prefix) == "table" then
            tbl = self:evaluateExpression(expr.prefix, scope)
        else
            error("Invalid index expression prefix type: " .. type(expr.prefix))
        end
        
        -- 验证index部分
        if not expr.index then
            error("Invalid index expression index: nil")
        end
        
        -- 确保对象有效
        if tbl == nil then
            error("Attempt to index a nil value in expression: " .. tostring(expr.prefix))
        end
        
        if type(tbl) ~= "table" then
            error("Attempt to index a value of type " .. type(tbl))
        end
        
        -- 再获取索引表达式的值
        local idx = self:evaluateExpression(expr.index, scope)
        return tbl[idx]
    end
    
    -- 执行成员表达式
    -- 处理表的成员访问操作，如table.member
    -- @param expr 成员表达式节点
    -- @param scope 当前执行的作用域
    -- @return 返回成员访问的结果
    function self:evaluateMember(expr, scope)
        -- 确保表达式结构有效
        if not expr then
            error("Invalid member expression: nil")
        end
        
        -- 先获取前缀表达式的值
        local tbl
        if type(expr.prefix) == "string" then
            -- 如果prefix是字符串，从作用域中查找
            tbl = scope[expr.prefix]
        else
            -- 否则作为表达式求值
            tbl = self:evaluateExpression(expr.prefix, scope)
        end
        
        -- 确保对象有效
        if tbl == nil then
            error("Attempt to access a member of a nil value")
        end
        
        -- 确保成员名存在
        if not expr.member then
            error("Invalid member expression: missing member name")
        end
        
        return tbl[expr.member]
    end
    
    -- 执行语句
    -- 根据语句类型分发到不同的处理函数进行执行
    -- @param statement 要执行的语句节点
    -- @param scope 当前执行的作用域
    -- @return 返回语句执行的结果（可能为nil）
    function self:evaluateStatement(statement, scope)
        if not statement then
            return
        end
        
        local stmtType = statement.type or "nil"
        
        -- 兼容新旧两种命名方式
        if stmtType == "expression_statement" or stmtType == "ExpressionStatement" then
            return self:evaluateExpression(statement.expression or statement, scope)
        elseif stmtType == "assignment" or stmtType == "Assignment" or stmtType == "AssignmentStatement" then
            return self:evaluateAssignment(statement, scope)
        elseif stmtType == "local_declaration" or stmtType == "LocalDeclaration" then
            return self:evaluateLocalDeclaration(statement, scope)
        elseif stmtType == "if_statement" or stmtType == "IfStatement" then
            return self:evaluateIfStatement(statement, scope)
        elseif stmtType == "while_statement" or stmtType == "WhileStatement" then
            return self:evaluateWhileStatement(statement, scope)
        elseif stmtType == "for_statement" or stmtType == "ForStatement" then
            return self:evaluateForStatement(statement, scope)
        elseif stmtType == "repeat_statement" or stmtType == "RepeatStatement" then
            return self:evaluateRepeatStatement(statement, scope)
        elseif stmtType == "function_definition" or stmtType == "FunctionDefinition" then
            return self:evaluateFunctionDefinition(statement, scope)
        elseif stmtType == "local_function" or stmtType == "LocalFunction" then
            return self:evaluateLocalFunction(statement, scope)
        elseif stmtType == "return_statement" or stmtType == "ReturnStatement" then
            return self:evaluateReturnStatement(statement, scope)
        elseif stmtType == "break" or stmtType == "BreakStatement" then
            return { type = "break" }
        end
        
        error("Unknown statement type: " .. tostring(stmtType))
    end
    
    -- 执行赋值语句
    -- 处理变量赋值操作，支持多重赋值
    -- @param statement 赋值语句节点
    -- @param scope 当前执行的作用域
    -- @return 返回最后一个表达式的值
    function self:evaluateAssignment(statement, scope)
        -- 处理简化的赋值表示法（兼容可能的新格式）
        if statement.targets and statement.expressions then
            local values = {}
            for i, expr in ipairs(statement.expressions) do
                values[i] = self:evaluateExpression(expr, scope)
            end
            
            for i, target in ipairs(statement.targets) do
                local value = values[i] or values[#values]
                self:assignValue(target, value, scope)
            end
            
            return values[#values]
        else
            -- 原始格式的赋值语句
            local rightValue = self:evaluateExpression(statement.right, scope)
            self:assignValue(statement.left, rightValue, scope)
            return rightValue
        end
    end
    
    -- 辅助函数：处理赋值目标
    -- 根据目标类型执行不同的赋值逻辑
    -- @param target 赋值目标（变量、索引、成员等）
    -- @param value 要赋的值
    -- @param scope 当前执行的作用域
    function self:assignValue(target, value, scope)
        local targetType = target.type or "nil"
        
        if targetType == "identifier" or targetType == "Identifier" then
            scope[target.name] = value
        elseif targetType == "index" or targetType == "Index" or targetType == "IndexExpression" then
            -- 处理target.prefix可能是字符串的情况
            local tbl
            if type(target.prefix) == "string" then
                -- 如果是字符串，直接从scope中获取
                tbl = scope[target.prefix]
            else
                -- 否则正常调用evaluateExpression
                tbl = self:evaluateExpression(target.prefix, scope)
            end
            if tbl == nil then
                error("Attempt to index a nil value in assignValue: " .. tostring(target.prefix))
            end
            if type(tbl) ~= "table" then
                error("Attempt to index a value of type " .. type(tbl))
            end
            local idx = self:evaluateExpression(target.index, scope)
            tbl[idx] = value
        elseif targetType == "member" or targetType == "Member" or targetType == "MemberExpression" then
            local tbl = self:evaluateExpression(target.prefix, scope)
            if tbl == nil then
                error("Attempt to index a nil value")
            end
            if type(tbl) ~= "table" then
                error("Attempt to index a value of type " .. type(tbl))
            end
            tbl[target.member] = value
        else
            error("Invalid assignment target: " .. tostring(targetType))
        end
    end
    
    -- 执行局部变量声明
    -- 处理local变量的定义和初始化
    -- @param statement 局部变量声明语句节点
    -- @param scope 当前执行的作用域
    -- @return 返回最后一个初始化表达式的值
    function self:evaluateLocalDeclaration(statement, scope)
        local values = {}
        for i, valueExpr in ipairs(statement.values) do
            values[i] = self:evaluateExpression(valueExpr, scope)
        end
        
        -- 正确处理局部变量声明
        -- 局部变量应该只在声明它的作用域中可见
        -- 使用rawset直接设置到当前作用域，不通过__newindex元方法
        for i, name in ipairs(statement.names) do
            rawset(scope, name, values[i] or nil)
        end
        
        return #values > 0 and values[#values] or nil
    end
    
    -- 移除重复的evaluateBinaryOp函数定义
    
    -- 执行if语句
    -- 处理条件判断和分支执行
    -- @param statement if语句节点
    -- @param scope 当前执行的作用域
    -- @return 返回执行的代码块的最后一个表达式的值
    function self:evaluateIfStatement(statement, scope)
        -- 对于if语句，我们需要在当前作用域中执行代码块，
        -- 但同时让代码块内的局部变量声明只在块内有效
        -- 为了实现这一点，我们修改evaluateBlock函数的调用方式
        -- 但保留evaluateBlock内部创建新作用域的逻辑
        if self:evaluateExpression(statement.condition, scope) then
            return self:evaluateBlock(statement.body, scope)
        end
        
        for _, elseifClause in ipairs(statement.elseifs) do
            if self:evaluateExpression(elseifClause.condition, scope) then
                return self:evaluateBlock(elseifClause.body, scope)
            end
        end
        
        if statement.else_body then
            return self:evaluateBlock(statement.else_body, scope)
        end
        
        return nil
    end
    
    -- 执行while语句
    -- 处理循环执行逻辑
    -- @param statement while语句节点
    -- @param scope 当前执行的作用域
    -- @return 返回循环体最后一次执行的结果
    function self:evaluateWhileStatement(statement, scope)
        local lastResult = nil
        
        while self:evaluateExpression(statement.condition, scope) do
            local result = self:evaluateBlock(statement.body, self:createScope(scope))
            
            if type(result) == "table" and result.type == "break" then
                break
            end
            
            lastResult = result
        end
        
        return lastResult
    end
    
    -- 执行for语句
    -- 处理数值for循环
    -- @param statement for语句节点
    -- @param scope 当前执行的作用域
    -- @return 返回循环体最后一次执行的结果
    function self:evaluateForStatement(statement, scope)
        local start = self:evaluateExpression(statement.start, scope)
        local finish = self:evaluateExpression(statement.finish, scope)
        local step = statement.step and self:evaluateExpression(statement.step, scope) or 1
        
        local loopScope = self:createScope(scope)
        local lastResult = nil
        
        for i = start, finish, step do
            loopScope[statement.variable] = i
            local result = self:evaluateBlock(statement.body, loopScope)
            
            if type(result) == "table" and result.type == "break" then
                break
            end
            
            lastResult = result
        end
        
        return lastResult
    end
    
    -- 执行repeat语句
    -- 处理repeat-until循环，先执行后判断
    -- @param statement repeat语句节点
    -- @param scope 当前执行的作用域
    -- @return 返回循环体最后一次执行的结果
    function self:evaluateRepeatStatement(statement, scope)
        local loopScope = self:createScope(scope)
        local lastResult = nil
        
        repeat
            lastResult = self:evaluateBlock(statement.body, loopScope)
            
            if type(lastResult) == "table" and lastResult.type == "break" then
                break
            end
            
        until self:evaluateExpression(statement.condition, loopScope)
        
        return lastResult
    end
    
    -- 执行函数定义
    -- 创建函数对象并绑定到相应的变量或表成员
    -- @param statement 函数定义语句节点
    -- @param scope 当前执行的作用域
    -- @return 返回定义的函数对象
    function self:evaluateFunctionDefinition(statement, scope)
        -- 创建闭包函数
        local func = function(...)
            local args = { ... }
            local funcScope = self:createScope(scope)
            
            -- 设置参数
            for i, paramName in ipairs(statement.parameters) do
                funcScope[paramName] = args[i]
            end
            
            -- 执行函数体
            local result = self:evaluateBlock(statement.body, funcScope)
            
            -- 直接返回结果，因为evaluateBlock已经处理了return语句
            return result
        end
        
        -- 处理方法定义 (obj:method)
        if statement.name and string.find(statement.name, ":") then
            local parts = {}
            for part in string.gmatch(statement.name, "[^:]+") do
                table.insert(parts, part)
            end
            
            if #parts == 2 then
                if not scope[parts[1]] then
                    scope[parts[1]] = {}
                end
                
                -- 调整函数为方法形式，添加self参数
                local method = function(self, ...)
                    local args = { ... }
                    local funcScope = self:createScope(scope)
                    funcScope["self"] = self
                    
                    -- 设置参数
                    for i, paramName in ipairs(statement.parameters) do
                        funcScope[paramName] = args[i]
                    end
                    
                    -- 执行函数体
                    local result = self:evaluateBlock(statement.body, funcScope)
                    
                    -- 直接返回结果，因为evaluateBlock已经处理了return语句
                    return result
                end
                
                scope[parts[1]][parts[2]] = method
            end
        else
            -- 普通函数定义或匿名函数
            if statement.name then
                scope[statement.name] = func
            end
        end
        
        return func
    end
    
    -- 执行局部函数定义
    -- 创建局部函数对象并绑定到局部变量
    -- @param statement 局部函数定义语句节点
    -- @param scope 当前执行的作用域
    -- @return 返回定义的函数对象
    function self:evaluateLocalFunction(statement, scope)
        -- 创建闭包函数
        local func = function(...)
            local args = { ... }
            local funcScope = self:createScope(scope)
            
            -- 设置参数
            for i, paramName in ipairs(statement.parameters) do
                funcScope[paramName] = args[i]
            end
            
            -- 执行函数体
            local result = self:evaluateBlock(statement.body, funcScope)
            
            -- 处理返回值 - 直接返回结果，因为evaluateBlock已经处理了return语句
            return result
        end
        
        scope[statement.name] = func
        return func
    end
    
    -- 执行return语句
    -- 处理函数返回值
    -- @param statement return语句节点
    -- @param scope 当前执行的作用域
    -- @return 返回包含返回值的表对象
    function self:evaluateReturnStatement(statement, scope)
        local values = {}
        for i, expr in ipairs(statement.expressions) do
            values[i] = self:evaluateExpression(expr, scope)
        end
        
        return { type = "return", values = values }
    end
    
    -- 执行代码块
    -- 按顺序执行代码块中的语句，创建新的作用域
    -- @param block 代码块节点
    -- @param scope 当前执行的作用域
    -- @return 返回代码块最后一个表达式的值
    function self:evaluateBlock(block, scope)
        -- 为代码块创建新的作用域，以正确处理局部变量
        local blockScope = self:createScope(scope)
        local lastResult = nil
        
        for _, statement in ipairs(block.statements) do
            lastResult = self:evaluateStatement(statement, blockScope)
            
            -- 处理return语句，提取实际的返回值
            if type(lastResult) == "table" then
                if lastResult.type == "return" then
                    -- 对于return语句，返回第一个值或nil
                    return lastResult.values[1] or nil
                elseif lastResult.type == "break" then
                    return lastResult
                end
            end
        end
        
        return lastResult
    end
    
    -- 执行整个程序
    -- 设置全局作用域并启动程序执行
    -- @return 返回程序执行的结果
    function self:evaluateProgram()
        -- 确保全局作用域能够访问和修改sandbox
        self.globalScope = self:createScope()
        setmetatable(self.globalScope, {
            __index = function(t, k)
                if self.sandbox[k] ~= nil then
                    return self.sandbox[k]
                end
                return nil
            end,
            __newindex = function(t, k, v)
                rawset(t, k, v)
                -- 同时保存到sandbox中，以便外部访问
                self.sandbox[k] = v
            end
        })
        return self:evaluateBlock(self.ast.block, self.globalScope)
    end
    
    return self
end

return evaluator
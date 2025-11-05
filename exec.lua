-- Lua解释器执行入口模块
-- 本模块提供了执行Lua代码的主要函数，整合了词法分析、语法分析和代码执行的完整流程。
-- 是连接用户代码和解释器内部组件的桥梁，提供了简单统一的API接口。

-- 导入必要的模块组件
-- lexer: 词法分析器，负责将源代码转换为token流
-- parser: 语法分析器，负责将token流解析为抽象语法树
-- evaluator: 代码评估器，负责执行抽象语法树
local lexer = require("lexer")
local parser = require("parser")
local evaluator = require("evaluator")

-- 执行Lua代码的主函数
-- 将Lua源代码转换为token流，解析为抽象语法树，然后执行并返回结果
-- @param code 要执行的Lua源代码字符串
-- @param sandbox 可选的沙盒环境表，用于提供和限制全局变量
-- @return 返回代码执行的结果
function executeLuaCode(code, sandbox)
  -- 参数验证：确保代码是有效的字符串
  if not code or type(code) ~= "string" then
    error("executeLuaCode: 代码必须是一个非空字符串")
  end

  -- 创建默认沙盒环境
  -- 如果未提供沙盒，则创建一个包含当前全局环境所有变量的新表
  if not sandbox then
    sandbox = {}
    for i, j in pairs(_G) do
      sandbox[i] = j
    end
  end

  -- 执行词法分析
  -- 创建词法分析器实例并获取所有token
  local lex = lexer.new(code)
  local tokens = lex:getAllTokens()

  -- 检查是否有词法错误
  -- 遍历token流，查找并报告词法分析阶段的错误
  for _, token in ipairs(tokens) do
    if token.type == "error" then
      error("词法分析失败: " .. tostring(token.value) .. " (行 " .. token.line .. ", 列 " .. token.column .. ")")
    end
  end

  -- 执行语法分析
  -- 创建一个简单的lexer包装器，因为parser期望一个有nextToken方法的lexer
  local tokensLexer = {
    tokens = tokens,
    position = 1,
    nextToken = function(self)
      if self.position <= #self.tokens then
        local token = self.tokens[self.position]
        self.position = self.position + 1
        return token
      end
      return { type = "EOF", value = nil, line = 1, column = 1 }
    end
  }

  -- 创建解析器实例并解析程序
  local parse = parser.new(tokensLexer)
  local ast
  local success, err = pcall(function()
    ast = parse:parseProgram()
  end)

  -- 处理语法分析错误
  if not success then
    error("语法分析失败: " .. tostring(err))
  end

  -- 执行代码
  -- 创建评估器实例并尝试执行代码
  local eval = evaluator.new(ast, sandbox)
  local result
  local success, err = pcall(function()
    -- 查找evaluate方法或者其他执行方法
    -- 兼容不同版本的评估器接口
    if eval.evaluate then
      result = eval:evaluate()
    elseif eval.execute then
      result = eval:execute()
    elseif eval.evaluateProgram then
      result = eval:evaluateProgram(eval:createScope())
    else
      -- 如果没有直接的执行方法，尝试执行AST的根节点
      result = eval:evaluateExpression(ast, eval:createScope())
    end
  end)

  -- 处理执行错误
  if not success then
    error("执行失败: " .. tostring(err))
  end

  -- 返回代码执行的结果
  return result
end

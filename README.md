# Lua解释器蛋仔版

这是一个用Lua语言实现的简化版Lua解释器（适用于蛋仔沙盒环境），遵循经典的解释器设计模式，包含词法分析、语法分析和代码执行三个主要阶段。

## 项目结构

```
Lua解释器蛋仔版/
├── lexer.lua       # 词法分析器
├── parser.lua      # 语法分析器
├── evaluator.lua   # 代码评估器
└── exec.lua        # 执行入口
```

## 模块介绍

### 1. 词法分析器 (lexer.lua)

词法分析器负责将Lua源代码文本转换为标记(tokens)序列。

**主要功能：**
- 识别Lua关键字（如`if`, `for`, `function`等）
- 解析标识符、数字、字符串等字面量
- 识别运算符、分隔符等特殊符号
- 处理注释和空白字符
- 生成带有位置信息的标记序列

### 2. 语法分析器 (parser.lua)

语法分析器将词法分析产生的标记序列转换为抽象语法树(AST)。

**主要功能：**
- 实现递归下降解析算法
- 解析表达式（算术、逻辑、关系等）
- 解析语句（赋值、控制流、函数定义等）
- 构建层次化的抽象语法树
- 进行语法错误检查

### 3. 代码评估器 (evaluator.lua)

评估器负责遍历和执行抽象语法树，实现Lua代码的实际执行。

**主要功能：**
- 实现作用域和变量管理
- 执行各种表达式和语句
- 处理函数调用和闭包
- 实现控制流（条件、循环）
- 提供沙盒环境隔离执行

### 4. 执行入口 (exec.lua)

执行入口整合了前面三个模块，提供统一的代码执行接口。

**主要功能：**
- 接收Lua代码字符串和可选的沙盒环境
- 协调词法分析、语法分析和代码执行
- 错误处理和异常捕获
- 返回执行结果

## 使用方法

### 基本用法

```lua
-- 导入执行模块
require("exec")

-- 执行简单的Lua代码
local result = executeLuaCode("return 1 + 1")
print(result)  -- 输出: 2

-- 执行复杂的Lua代码块
local code = [[
local sum = 0
for i = 1, 10 do
    sum = sum + i
end
return sum
]]

result = executeLuaCode(code)
print(result)  -- 输出: 55
```

### 使用自定义沙盒

```lua
-- 创建自定义沙盒环境
local customSandbox = {
    print = function(msg)
        print("[自定义输出]: " .. msg)
    end,
    math = math
}

-- 在自定义沙盒中执行代码
executeLuaCode([[
print("Hello, World!")
print("π ≈ " .. math.pi)
]], customSandbox)
```

## 限制

这个解释器实现了Lua语言的核心功能，但可能存在以下限制：

- 某些高级特性可能未完全支持（如协程、元表等）
- 错误处理和调试信息可能不如官方Lua解释器完善
- 性能可能低于原生Lua解释器

## 示例

```lua
-- 执行一个包含函数和表操作的示例
local code = [[
-- 定义一个函数计算斐波那契数列
local function fibonacci(n)
    if n <= 1 then
        return n
    end
    return fibonacci(n-1) + fibonacci(n-2)
end

-- 创建一个表并填充数据
local numbers = {}
for i = 1, 10 do
    numbers[i] = fibonacci(i)
end

-- 返回结果表
return numbers
]]

local fibResult = executeLuaCode(code)

-- 打印结果
for i, v in ipairs(fibResult) do
    print("fibonacci(" .. i .. ") = " .. v)
end
```

## 开发说明

### 词法分析

词法分析器使用有限状态机来识别各种Lua语法元素，生成的标记包含类型、值和位置信息，为后续的语法分析提供基础。

### 语法分析

语法分析器采用递归下降解析算法，按照Lua语法规则构建抽象语法树。解析过程遵循运算符优先级规则，确保表达式计算的正确性。

### 代码执行

评估器采用深度优先遍历的方式执行抽象语法树，通过作用域链实现变量查找和闭包支持，完整实现了Lua的核心执行逻辑。

## 许可证

[MIT License](https://opensource.org/licenses/MIT)


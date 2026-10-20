// 短代码回归语料：识别与性能测试共用，避免只验证完整、大段示例代码。
const diaryCodeSamples = <String, String>{
  'dart': '''
void main() {
  final message = 'Hello';
  print(message);
}''',
  'python': '''
def greet(name):
    return f"Hello, {name}!"''',
  'javascript': r'''
const greet = (name) => {
  console.log(`Hello, ${name}!`);
};''',
  'typescript': '''
const greet = (name: string): void => {
  console.log(name);
};''',
  'java': '''
public class Hello {
  public static void main(String[] args) {
    System.out.println("Hello");
  }
}''',
  'kotlin': '''
fun main() {
  val name = "world"
  println("Hello, \$name")
}''',
  'swift': '''
func greet(_ name: String) -> String {
  return "Hello, " + name
}''',
  'cpp': '''
#include <iostream>
int main() {
  std::cout << "Hello" << std::endl;
}''',
  'cs': '''
using System;
class Hello {
  static void Main() {
    Console.WriteLine("Hello");
  }
}''',
  'go': '''
package main
import "fmt"
func main() {
  fmt.Println("Hello")
}''',
  'rust': '''
fn main() {
  let mut count = 0;
  println!("Hello {}", count);
}''',
  'php': '''
<?php
\$name = "world";
echo "Hello, " . \$name;''',
  'ruby': '''
def greet(name)
  puts "Hello, #{name}!"
end''',
  'lua': '''
local function greet(name)
  print("Hello, " .. name)
end''',
  'bash': '''
#!/bin/bash
for file in *.txt; do
  echo "\$file"
done''',
  'sql': 'SELECT title FROM diaries WHERE id = 1;',
  'json': '{"name": "jotsy", "active": true}',
  'yaml': '''
name: jotsy
dependencies:
  flutter:
    sdk: flutter''',
  'xml': '<div class="note">Hello <strong>world</strong></div>',
  'css': '''
.note {
  color: #336699;
  padding: 12px;
}''',
  'markdown': '''
# Today

- Write a note
- Read [a book](https://example.com)''',
  'diff': '''
--- a/note.txt
+++ b/note.txt
@@ -1 +1 @@
-old note
+new note''',
};

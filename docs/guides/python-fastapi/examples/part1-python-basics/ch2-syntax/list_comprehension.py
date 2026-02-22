# 第2章: List Comprehension実例

# Ruby: [1,2,3,4,5].select { |x| x.even? }.map { |x| x * 2 }
# Python: ワンライナーで表現

numbers = [1, 2, 3, 4, 5]

# 偶数のみフィルタして2倍
result = [x * 2 for x in numbers if x % 2 == 0]
print(result)  # [4, 8]

# 辞書版
users = {"alice": 25, "bob": 30, "charlie": 35}
adults = {name: age for name, age in users.items() if age >= 30}
print(adults)  # {'bob': 30, 'charlie': 35}

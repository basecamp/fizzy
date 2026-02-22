# 第2章 演習1解答: Ruby→Python変換

class Calculator:
    """
    Rubyの Calculator クラスをPythonに変換

    ポイント:
    - initialize → __init__
    - @x → self.x
    - 明示的なreturn必須
    - 型ヒント追加（ベストプラクティス）
    """
    def __init__(self, x: int, y: int):
        self.x = x
        self.y = y

    def add(self) -> int:
        return self.x + self.y  # return必須！

    def multiply(self) -> int:
        return self.x * self.y


# テスト
if __name__ == "__main__":
    calc = Calculator(5, 3)
    print(calc.add())       # 8
    print(calc.multiply())  # 15

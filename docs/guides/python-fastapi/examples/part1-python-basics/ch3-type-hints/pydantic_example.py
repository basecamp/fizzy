# 第3章: Pydanticバリデーション実例

from pydantic import BaseModel, EmailStr, Field, ValidationError

class User(BaseModel):
    """Rails Strong Parameters相当のバリデーション"""
    name: str = Field(min_length=1, max_length=100)
    email: EmailStr
    age: int = Field(ge=0, le=150)

# 正常ケース
try:
    user = User(name="John Doe", email="john@example.com", age=30)
    print(f"✅ Valid user: {user.name}, {user.email}")
except ValidationError as e:
    print(f"❌ Validation error: {e}")

# エラーケース
try:
    invalid_user = User(name="", email="invalid", age=-1)
except ValidationError as e:
    print(f"❌ Validation errors:")
    for error in e.errors():
        print(f"  - {error['loc']}: {error['msg']}")

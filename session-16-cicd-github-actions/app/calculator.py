"""Pure calculator functions (the business logic that the unit tests cover)."""

OPERATIONS = ("add", "subtract", "multiply", "divide")


def add(a: float, b: float) -> float:
    return a + b


def subtract(a: float, b: float) -> float:
    return a - b


def multiply(a: float, b: float) -> float:
    return a * b


def divide(a: float, b: float) -> float:
    if b == 0:
        raise ValueError("Cannot divide by zero")
    return a / b


def calculate(operation: str, a: float, b: float) -> float:
    """Dispatch an operation name to the matching function."""
    funcs = {
        "add": add,
        "subtract": subtract,
        "multiply": multiply,
        "divide": divide,
    }
    if operation not in funcs:
        raise ValueError(f"Unknown operation '{operation}'. Valid: {', '.join(OPERATIONS)}")
    return funcs[operation](a, b)

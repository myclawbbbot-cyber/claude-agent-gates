import pytest
from pager import page_count


def test_exact_multiple():
    assert page_count(9, 3) == 3


def test_exact_multiple_two():
    assert page_count(6, 3) == 2


def test_zero_items():
    assert page_count(0, 3) == 0


def test_invalid_per_page():
    with pytest.raises(ValueError):
        page_count(10, 0)

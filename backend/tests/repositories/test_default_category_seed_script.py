from scripts.seed_default_categories import main


def test_seed_script_prints_palette_defaults_and_gray_uncategorized(capsys):
    main()
    assert capsys.readouterr().out.splitlines() == [
        "취업 #64B5F6",
        "공부 #5BD89D",
        "업무 팁 #FF6277",
        "생활 꿀팁 #FFA24B",
        "장소 #FFD75C",
        "제품 추천 #B9AAFF",
        "미분류 #6B7280",
    ]

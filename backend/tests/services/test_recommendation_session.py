from app.db.session import RecommendationSessionLocal, engine, recommendation_engine
from app.services import usage_limits


def test_recommendation_records_use_the_product_dedicated_pool():
    assert usage_limits.RecommendationSessionLocal is RecommendationSessionLocal
    assert RecommendationSessionLocal.kw["bind"] is recommendation_engine
    pool = recommendation_engine.pool
    assert pool is not engine.pool
    assert pool.size() == 2
    assert pool._max_overflow == 0
    assert pool.timeout() == 2
    assert pool._pre_ping is True

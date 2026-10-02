"""Caps what Quincena's Firebase project can ask Gemini for.

    python3 tool/firebase/caps.py           # set the caps, then show them
    python3 tool/firebase/caps.py --check   # only show them

Every cap here is enforced by Google before a request reaches the model:
past it, the request fails with 429 and costs nothing. They are the limits
that stop spending; budgets only warn. See docs/PRODUCTION.md.

On the free tier only the per-person limit applies, next to Google's own
free-tier limits. The others apply once the project pays for Gemini, on
whichever paid tier it is.
"""
import json
import sys

from quota import effective, set_override

AI_LOGIC = 'firebasevertexai.googleapis.com'
GEMINI = 'generativelanguage.googleapis.com'

# Requests each person may send in a minute through Firebase AI Logic. A
# question takes two or three. The Live API, which the app does not use,
# gets none.
PER_PERSON = 20

# The two models the app asks, in requests per minute and per day for the
# whole project. Every other model gets nothing, nor do priority processing,
# images and video, so a stolen App Check token cannot reach them.
PER_MINUTE = {'gemini-3.8-flash': 60, 'gemini-3.5-flash': 30}
PER_DAY = {'gemini-3.8-flash': 300, 'gemini-3.5-flash': 100}

PER_PERSON_LIMITS = [
    (AI_LOGIC, 'generate_content_requests_per_minute_per_project_per_user',
     '/min/project/region/user', PER_PERSON),
    (AI_LOGIC, 'bidi_generate_content_requests_per_minute_per_project_per_user',
     '/min/project/region/user', 0),
]

TEXT = [
    ('generate_requests_per_model', '/min/model/project', PER_MINUTE),
    ('generate_requests_per_model_per_day', '/d/model/project', PER_DAY),
    ('generate_content_paid_tier_2_requests', '/min/model/project', PER_MINUTE),
    ('generate_content_paid_tier_2_requests', '/d/model/project', PER_DAY),
    ('generate_content_paid_tier_3_requests', '/min/model/project', PER_MINUTE),
    ('generate_content_paid_tier_3_requests', '/d/model/project', PER_DAY),
]

BLOCKED = [
    ('generate_content_paid_tier_2_requests_prio', '/min/model/project'),
    ('generate_content_paid_tier_2_requests_prio', '/d/model/project'),
    ('generate_content_paid_tier_3_requests_prio', '/min/model/project'),
    ('generate_content_paid_tier_3_requests_prio', '/d/model/project'),
    ('generated_images_paid_tier_1_per_model', '/d/model/project'),
    ('predict_requests_per_model', '/min/model/project'),
    ('predict_requests_per_model_per_day_paid_tier_1', '/d/model/project'),
    ('predict_requests_per_model_paid_tier_2', '/min/model/project'),
    ('predict_requests_per_model_per_day_paid_tier_2', '/d/model/project'),
    ('predict_requests_per_model_paid_tier_3', '/min/model/project'),
    ('predict_requests_per_model_per_day_paid_tier_3', '/d/model/project'),
    ('predict_long_running_requests_per_model', '/min/model/project'),
    ('predict_long_running_requests_per_model_per_day', '/d/model/project'),
    ('predict_long_running_requests_per_model_paid_tier_2', '/min/model/project'),
    ('predict_long_running_requests_per_model_per_day_paid_tier_2',
     '/d/model/project'),
    ('predict_long_running_requests_per_model_paid_tier_3', '/min/model/project'),
    ('predict_long_running_requests_per_model_per_day_paid_tier_3',
     '/d/model/project'),
]


def apply():
    for service, metric, limit, value in PER_PERSON_LIMITS:
        print(metric, set_override(service, metric, limit, value))
    for metric, limit, caps in TEXT:
        # The models first: until they have their own, the zero for every
        # other model would hold for them too.
        for model, value in caps.items():
            print(metric, limit, model, set_override(
                GEMINI, metric, limit, value, {'model': model}))
        print(metric, limit, 'other models', set_override(
            GEMINI, metric, limit, 0))
    for metric, limit in BLOCKED:
        print(metric, limit, set_override(GEMINI, metric, limit, 0))


def show():
    def value(v):
        return v[0] if v[0] is not None else '0'

    for service, metric, limit, _ in PER_PERSON_LIMITS:
        values = {value(v) for v in effective(service, metric, limit).values()}
        print(f'{metric}: {", ".join(sorted(values))} a minute per person')
    for metric, limit, _ in TEXT:
        buckets = {json.loads(k).get('model', ''): v
                   for k, v in effective(GEMINI, metric, limit).items()}
        open_models = sorted(m for m, v in buckets.items()
                             if v[0] is not None and m not in PER_MINUTE)
        mine = ', '.join(f'{m} {value(buckets[m])}'
                         for m in PER_MINUTE if m in buckets)
        print(f'{metric} {limit}: {mine}; other models open: '
              f'{open_models or "none"}')
    for metric, limit in BLOCKED:
        open_models = sorted(json.loads(k).get('model', '(default)')
                             for k, v in effective(GEMINI, metric, limit).items()
                             if v[0] is not None)
        print(f'{metric} {limit}: open: {open_models or "none"}')


if __name__ == '__main__':
    if '--check' not in sys.argv:
        apply()
    show()

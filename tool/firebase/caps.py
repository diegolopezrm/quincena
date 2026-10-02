"""Caps what Quincena's Firebase project can ask Gemini for.

    python3 tool/firebase/caps.py           # set the caps, then show them
    python3 tool/firebase/caps.py --check   # only show them

Every cap here is enforced by Google before a request reaches the model:
past it, the request fails with 429 and costs nothing. They are the limits
that stop spending; budgets only warn. See docs/PRODUCTION.md.

The app asks Gemini through Agent Platform on the global location, where
the models run on dynamic shared quota: Google does not apply a project's
overrides to them (checked on 2 October 2026, when a model set to zero still
answered). There, what stops spending is the spend cap on Agent Platform
(docs/PRODUCTION.md), and the per-person limit below. The daily input-token
budgets for the two models stay set in case Google starts applying them.

Every other location and kind of request on Agent Platform is closed where
Google applies the limit, and the Gemini Developer API, which the app no
longer uses, is closed entirely.
"""
import json
import sys

from quota import effective, rest, limit_path, set_override

AI_LOGIC = 'firebasevertexai.googleapis.com'
AGENT = 'aiplatform.googleapis.com'
DEVELOPER = 'generativelanguage.googleapis.com'

# Requests each person may send in a minute through Firebase AI Logic, on
# either backend. A question takes two or three. The Live API, which the app
# does not use, gets none.
PER_PERSON = 20

# Agent Platform on the global location, for the whole project. A question
# sends about 25,000 input tokens: the daily budgets are some 240 questions
# on 3.8 Flash and 80 on 3.5 Flash, about US$7.50 on a day at both limits.
INPUT_TOKENS_PER_DAY = {'gemini-3.8-flash': 6_000_000,
                        'gemini-3.5-flash': 2_000_000}

PER_PERSON_LIMITS = [
    (AI_LOGIC, 'generate_content_requests_per_minute_per_project_per_user',
     '/min/project/region/user', PER_PERSON),
    (AI_LOGIC, 'bidi_generate_content_requests_per_minute_per_project_per_user',
     '/min/project/region/user', 0),
]

# (service, metric, limit, the models' values)
OPEN = [
    # Despite its name, this limit counts a day.
    (AGENT, 'global_generate_content_input_tokens_per_minute_per_base_model',
     '/d/base_model/project', INPUT_TOKENS_PER_DAY),
]

CLOSED = [
    # Agent Platform anywhere but global, and what the app never asks for.
    (AGENT, 'generate_content_requests_per_minute_per_project_per_base_model',
     '/min/base_model/project/region'),
    (AGENT, 'online_prediction_requests', '/min/project/region'),
    (AGENT, 'online_prediction_requests_per_base_model',
     '/min/base_model/project/region'),
    (AGENT, 'us_multi_region_online_prediction_requests_per_base_model',
     '/min/base_model/project'),
    (AGENT, 'eu_multi_region_online_prediction_requests_per_base_model',
     '/min/base_model/project'),
    (AGENT, 'global_responses_requests_per_minute_per_project_per_base_model',
     '/min/base_model/project'),
    (AGENT, 'responses_requests_per_minute_per_project_per_base_model',
     '/min/base_model/project/region'),
    (AGENT, 'us_multi_region_responses_requests_per_minute_per_base_model',
     '/min/base_model/project'),
    (AGENT, 'eu_multi_region_responses_requests_per_minute_per_base_model',
     '/min/base_model/project'),
    (AGENT, 'generate_content_image_gen_per_project_per_base_model',
     '/min/base_model/project/region'),
    (AGENT, 'generate_content_audio_gen_per_project_per_base_model_global',
     '/min/base_model/project'),
    (AGENT, 'generate_content_audio_gen_per_project_per_base_model',
     '/min/base_model/project/region'),
    (AGENT, 'bidi_gen_concurrent_reqs_per_project_per_base_model_global',
     '/10min/base_model/project'),
    (AGENT, 'bidi_gen_concurrent_reqs_per_project_per_base_model',
     '/10min/base_model/project/region'),
    (AGENT, 'long_running_online_prediction_requests', '/min/project/region'),
    (AGENT, 'flex_requests_per_minute_per_project_per_base_model',
     '/min/base_model/project'),
    (AGENT, 'global_embed_content_requests_per_minute_per_base_model',
     '/min/base_model/project'),
    # The Gemini Developer API, every tier.
    (DEVELOPER, 'generate_content_free_tier_requests', '/min/model/project'),
    (DEVELOPER, 'generate_content_free_tier_requests', '/d/model/project'),
    (DEVELOPER, 'generate_requests_per_model', '/min/model/project'),
    (DEVELOPER, 'generate_requests_per_model_per_day', '/d/model/project'),
    (DEVELOPER, 'generate_content_paid_tier_2_requests', '/min/model/project'),
    (DEVELOPER, 'generate_content_paid_tier_2_requests', '/d/model/project'),
    (DEVELOPER, 'generate_content_paid_tier_3_requests', '/min/model/project'),
    (DEVELOPER, 'generate_content_paid_tier_3_requests', '/d/model/project'),
    (DEVELOPER, 'generate_content_paid_tier_2_requests_prio', '/min/model/project'),
    (DEVELOPER, 'generate_content_paid_tier_2_requests_prio', '/d/model/project'),
    (DEVELOPER, 'generate_content_paid_tier_3_requests_prio', '/min/model/project'),
    (DEVELOPER, 'generate_content_paid_tier_3_requests_prio', '/d/model/project'),
    (DEVELOPER, 'generated_images_paid_tier_1_per_model', '/d/model/project'),
    (DEVELOPER, 'predict_requests_per_model', '/min/model/project'),
    (DEVELOPER, 'predict_requests_per_model_per_day_paid_tier_1',
     '/d/model/project'),
    (DEVELOPER, 'predict_long_running_requests_per_model', '/min/model/project'),
    (DEVELOPER, 'predict_long_running_requests_per_model_per_day',
     '/d/model/project'),
]


def _overrides(service, metric, limit):
    _, b = rest('GET', limit_path(service, metric, limit) + '/consumerOverrides')
    return b.get('overrides', [])


def _model(service):
    return 'base_model' if service == AGENT else 'model'


def apply():
    for service, metric, limit, value in PER_PERSON_LIMITS:
        print(metric, set_override(service, metric, limit, value))
    for service, metric, limit, caps in OPEN:
        # The models first: until they have their own, the zero for every
        # other model would hold for them too.
        for model, value in caps.items():
            print(metric, limit, model, set_override(
                service, metric, limit, value, {_model(service): model}))
        print(metric, limit, 'other models', set_override(
            service, metric, limit, 0))
    for service, metric, limit in CLOSED:
        # A model that kept an override of its own would stay open.
        for o in _overrides(service, metric, limit):
            if o.get('dimensions') and o.get('overrideValue', '0') != '0':
                print(metric, limit, o['dimensions'], set_override(
                    service, metric, limit, 0, o['dimensions']))
        print(metric, limit, 'everything', set_override(service, metric, limit, 0))


def _open_buckets(service, metric, limit, allowed=()):
    """The buckets of a limit that still let requests through."""
    found = []
    for key, (value, _) in effective(service, metric, limit).items():
        dims = json.loads(key)
        name = dims.get(_model(service)) or dims.get('region') or '(default)'
        if value is not None and value != '0' and name not in allowed:
            found.append(f'{name}={"unlimited" if value == "-1" else value}')
    return found


def show():
    def value(v):
        return '0' if v[0] is None else v[0]

    for service, metric, limit, _ in PER_PERSON_LIMITS:
        values = {value(v) for v in effective(service, metric, limit).values()}
        print(f'{metric}: {", ".join(sorted(values))} a minute per person')
    for service, metric, limit, caps in OPEN:
        buckets = {json.loads(k).get(_model(service), ''): v
                   for k, v in effective(service, metric, limit).items()}
        mine = ', '.join(f'{m} {value(buckets[m])}' for m in caps if m in buckets)
        rest_open = _open_buckets(service, metric, limit, allowed=caps)
        print(f'{metric} {limit}: {mine}; anything else open: '
              f'{rest_open or "no"}')
    for service, metric, limit in CLOSED:
        still = _open_buckets(service, metric, limit)
        print(f'{metric} {limit}: open: {still or "nothing"}')


if __name__ == '__main__':
    if '--check' not in sys.argv:
        apply()
    show()

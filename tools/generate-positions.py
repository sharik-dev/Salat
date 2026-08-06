"""Prints the JSON body for one position illustration, for NanoBanana.

    python3 tools/generate-positions.py pos_ruku > body.json
    curl -s --max-time 290 -X POST localhost:4747/generate \
         -H 'Content-Type: application/json' -d @body.json
    python3 tools/cutout.py /tmp/pos_ruku.png   # -> pos_ruku_cut.png, transparent

The "no facial features" clause is the whole point of this prompt. Do not
paraphrase it away when tweaking the wording.
"""
import json, sys
BASE = """ONE single square image, 1:1, FULL BLEED: the flat background colour touches all four edges. NO frame, NO border, NO rounded corners, NO drop shadow, NO watermark, NO signature, NO text, NO caption, NO arrows, NO numbers.

Subject: {subject}

ABSOLUTE RULE — THE HEAD IS COMPLETELY BLANK. No eyes, no eyebrows, no nose, no mouth, no ears, no hair strands, no facial outline, no skin tone. The head is a smooth solid featureless shape, the exact same flat colour as the body. This is a religious modesty requirement and it is not negotiable.

Style: flat vector illustration, single solid silhouette, no gradient, no texture, no shading, no highlight, no outline of a different colour. The figure is one uniform flat warm dark brown #3A3226. The background is one uniform flat sand beige #EFE3CC and nothing else — no floor line, no prayer mat, no mosque, no arch, no lantern, no plant, no ornament, no pattern, no light ray.

The man is young and slim, wearing a plain long ankle-length thobe with long sleeves and a simple small rounded cap. The garment silhouette is clean and calm.

LAYOUT: the figure is centred and fits entirely inside the middle 70% of the square, with generous empty background all around, because the outer band is cropped to a circle. Nothing touches any edge.
"""
SUBJECTS = {
 "pos_qiyam": "a young man standing upright in prayer, seen from the front, feet slightly apart, his right hand resting over his left hand on his chest, head very slightly lowered.",
 "pos_takbir": "a young man standing in prayer with both hands raised open beside his head at ear level, palms facing forward, elbows bent — the opening Takbir.",
 "pos_itidal": "a young man standing perfectly upright in prayer, seen from the front, arms hanging relaxed straight down at his sides, feet slightly apart.",
 "pos_ruku": "a young man in the bowing position of Muslim prayer (ruku), strict side view profile facing left. His torso is bent exactly 90 degrees so his BACK IS PERFECTLY FLAT AND HORIZONTAL, like a table top. His LEGS ARE COMPLETELY STRAIGHT AND VERTICAL, hips directly above the heels. His arms hang straight DOWN from the shoulders and his HANDS GRIP HIS KNEES — the hands are at knee height, not near the feet, not near the ground. His head is level with his flat back, looking down. He is NOT touching his toes and NOT curled over.",
 "pos_sujud": "a young man prostrating in prayer, seen from the side in profile, forehead and nose touching the ground, both palms flat on the ground beside his head, knees on the ground, hips raised, toes tucked under.",
 "pos_jalsa": "a young man sitting in prayer, seen from the side in profile, sitting on his folded left leg with the right foot upright on its toes, back straight, both hands resting flat on his thighs.",
 "pos_tashahhud": "a young man sitting in the tashahhud position of Muslim prayer, strict side view profile facing right. He sits on his folded left leg with the right foot upright on its toes, back straight. CRITICAL — THE ARMS AND HANDS: both forearms lie FLAT ALONG THE THIGHS, following the exact line of the thigh from hip to knee, and BOTH HANDS ARE PLACED ON TOP OF THE KNEES, TOUCHING THE KNEES, resting their whole weight on them. The right hand is a closed fist SITTING ON THE KNEECAP with only the index finger extended, and that finger tips slightly UPWARD from the fist while the fist itself STAYS IN CONTACT WITH THE KNEE. The silhouette of the arm must merge with the silhouette of the thigh — there is NO gap of background between forearm and thigh. The hand does NOT float, does NOT hover, does NOT reach out in front of the knee, does NOT extend past the knee into empty space, is NOT lifted, NOT horizontal in the air, NOT at chest height. The elbow stays against the side of the body. The left hand rests flat on the left knee the same way.",
 "pos_salam": "a young man kneeling in prayer, seen from the FRONT: both shoulders and the chest face the viewer squarely, he sits back on his folded legs, both hands flat on his thighs. ONLY HIS HEAD is turned to his right, shown in side profile — the closing greeting. Absolutely NO circle, NO disc, NO oval, NO halo, NO vignette, NO coloured shape behind him: the background is one single flat colour edge to edge.",
}
if __name__ == "__main__":
    key = sys.argv[1]
    print(json.dumps({"prompt": BASE.format(subject=SUBJECTS[key]),
                      "output": f"/tmp/{key}.png"}))

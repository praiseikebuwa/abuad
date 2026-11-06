import { Router, Request, Response } from 'express';
import { authenticateToken, optionalAuth, AuthenticatedRequest } from '../middleware/auth';
import { prisma } from '../config/db';

const router = Router();

// Fallback in-memory store if DB table sync is pending
interface LocalSticker {
  id: string;
  title: string;
  imageUrl: string;
  animatedUrl?: string;
  type: string; // STATIC, ANIMATED, DOODLE, PHOTO_CUT
  category: string;
  tags: string[];
  isPublic: boolean;
  usageCount: number;
  authorId: string;
  authorName?: string;
  createdAt: string;
}

const DEFAULT_STICKERS: LocalSticker[] = [
  {
    "id": "stk_blushing_happy_tears_pepe_sctvm7",
    "title": "Blushing Happy Tears Pepe",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/blushing_happy_tears_pepe_65956.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/blushing_happy_tears_pepe_65956.webp",
    "type": "ANIMATED",
    "category": "REACTION",
    "tags": [
      "pepe",
      "blushing",
      "tears",
      "happy",
      "reaction",
      "cute"
    ],
    "isPublic": true,
    "usageCount": 250,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:27.000Z"
  },
  {
    "id": "stk_holding_back_tears_cry_1b2uml",
    "title": "Holding Back Tears Cry",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/holding_back_tears_cry_67001.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/holding_back_tears_cry_67001.webp",
    "type": "ANIMATED",
    "category": "REACTION",
    "tags": [
      "crying",
      "tears",
      "holdingback",
      "sad",
      "reaction",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 245,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:27.981Z"
  },
  {
    "id": "stk_bombastic_side_eye_dog_9hbx4v",
    "title": "Bombastic Side Eye Dog",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/bombastic_side_eye_dog_67981.webp",
    "type": "STATIC",
    "category": "REACTION",
    "tags": [
      "dog",
      "sideeye",
      "bombastic",
      "judgmental",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 240,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:28.398Z"
  },
  {
    "id": "stk_sad_pepe_trembling_pr6rli",
    "title": "Sad Pepe Trembling",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/sad_pepe_trembling_68399.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/sad_pepe_trembling_68399.webp",
    "type": "ANIMATED",
    "category": "REACTION",
    "tags": [
      "pepe",
      "sad",
      "trembling",
      "crying",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 235,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:28.813Z"
  },
  {
    "id": "stk_cartman_cheerful_smile_20jsxs",
    "title": "Cartman Cheerful Smile",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/cartman_cheerful_smile_68813.webp",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "southpark",
      "cartman",
      "happy",
      "smile",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 230,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:29.235Z"
  },
  {
    "id": "stk_ishowspeed_hood_stare_7bcmz5",
    "title": "IShowSpeed Hood Stare",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/ishowspeed_hood_stare_69236.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/ishowspeed_hood_stare_69236.webp",
    "type": "ANIMATED",
    "category": "REACTION",
    "tags": [
      "ishowspeed",
      "speed",
      "stare",
      "hood",
      "reaction",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 225,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:30.009Z"
  },
  {
    "id": "stk_standing_cat_look_o8bltg",
    "title": "Standing Cat Look",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/standing_cat_look_70009.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/standing_cat_look_70009.webp",
    "type": "ANIMATED",
    "category": "ANIMATED",
    "tags": [
      "cat",
      "standing",
      "curious",
      "cute",
      "animated"
    ],
    "isPublic": true,
    "usageCount": 220,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:30.413Z"
  },
  {
    "id": "stk_mike_wazowski_stare_yzpm20",
    "title": "Mike Wazowski Stare",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/mike_wazowski_stare_70413.webp",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "mike",
      "wazowski",
      "monstersinc",
      "stare",
      "meme",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 215,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:31.088Z"
  },
  {
    "id": "stk_ishowspeed_gasp_shock_422wd8",
    "title": "IShowSpeed Gasp Shock",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/ishowspeed_gasp_shock_71089.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/ishowspeed_gasp_shock_71089.webp",
    "type": "ANIMATED",
    "category": "REACTION",
    "tags": [
      "ishowspeed",
      "speed",
      "shock",
      "gasp",
      "disbelief",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 210,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:32.143Z"
  },
  {
    "id": "stk_blue_emoji_cringe_pucker_y9w0nc",
    "title": "Blue Emoji Cringe Pucker",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/blue_emoji_cringe_pucker_72143.webp",
    "type": "STATIC",
    "category": "REACTION",
    "tags": [
      "emoji",
      "blue",
      "cringe",
      "pucker",
      "sour",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 205,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:32.544Z"
  },
  {
    "id": "stk_dancing_hamster_groove_q0a961",
    "title": "Dancing Hamster Groove",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/dancing_hamster_groove_72545.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/dancing_hamster_groove_72545.webp",
    "type": "ANIMATED",
    "category": "ANIMATED",
    "tags": [
      "hamster",
      "dancing",
      "groove",
      "cute",
      "animated"
    ],
    "isPublic": true,
    "usageCount": 200,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:32.984Z"
  },
  {
    "id": "stk_gamer_corsair_headset_laugh_9wvbqt",
    "title": "Gamer Corsair Headset Laugh",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/gamer_corsair_headset_laugh_72986.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/gamer_corsair_headset_laugh_72986.webp",
    "type": "ANIMATED",
    "category": "REACTION",
    "tags": [
      "gamer",
      "corsair",
      "headset",
      "gaming",
      "streamer",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 195,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:33.549Z"
  },
  {
    "id": "stk_mindblown_hands_on_head_a2kcbe",
    "title": "Mindblown Hands On Head",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/mindblown_hands_on_head_73549.webp",
    "type": "STATIC",
    "category": "REACTION",
    "tags": [
      "shock",
      "mindblown",
      "hands on head",
      "disbelief",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 190,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:34.267Z"
  },
  {
    "id": "stk_tiger_woods_stealth_pass_hcttbk",
    "title": "Tiger Woods Stealth Pass",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/tiger_woods_stealth_pass_74268.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/tiger_woods_stealth_pass_74268.webp",
    "type": "ANIMATED",
    "category": "MEME",
    "tags": [
      "tigerwoods",
      "golf",
      "prank",
      "sports",
      "funny"
    ],
    "isPublic": true,
    "usageCount": 185,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:34.650Z"
  },
  {
    "id": "stk_puppy_with_painted_eyebrows_fjpxii",
    "title": "Puppy with Painted Eyebrows",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/puppy_with_painted_eyebrows_74650.jpeg",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "dog",
      "puppy",
      "eyebrows",
      "cute",
      "funny",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 180,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:35.052Z"
  },
  {
    "id": "stk_patrick_star_board_on_head_0hq5q2",
    "title": "Patrick Star Board On Head",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/patrick_star_board_on_head_75053.webp",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "spongebob",
      "patrick",
      "board",
      "hammer",
      "classic",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 175,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:35.481Z"
  },
  {
    "id": "stk_chad_doge_nod_8owc1i",
    "title": "Chad Doge Nod",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/chad_doge_nod_75481.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/chad_doge_nod_75481.webp",
    "type": "ANIMATED",
    "category": "ANIMATED",
    "tags": [
      "doge",
      "green",
      "chad",
      "smooth",
      "animated",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 170,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:35.930Z"
  },
  {
    "id": "stk_cheeky_big_smile_kid_cy0oyt",
    "title": "Cheeky Big Smile Kid",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/cheeky_big_smile_kid_75931.jpeg",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "kid",
      "smile",
      "cheeky",
      "happy",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 165,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:36.328Z"
  },
  {
    "id": "stk_orange_cat_boxer_punch_fyv6yh",
    "title": "Orange Cat Boxer Punch",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/orange_cat_boxer_punch_76329.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/orange_cat_boxer_punch_76329.webp",
    "type": "ANIMATED",
    "category": "ANIMATED",
    "tags": [
      "cat",
      "boxing",
      "punch",
      "fight",
      "animated",
      "funny"
    ],
    "isPublic": true,
    "usageCount": 160,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:37.007Z"
  },
  {
    "id": "stk_suspicious_boy_glance_flaudg",
    "title": "Suspicious Boy Glance",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/suspicious_boy_glance_77007.jpeg",
    "type": "STATIC",
    "category": "REACTION",
    "tags": [
      "boy",
      "suspicious",
      "glance",
      "side eye",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 155,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:37.585Z"
  },
  {
    "id": "stk_ishowspeed_stunned_look_up_niig8p",
    "title": "IShowSpeed Stunned Look Up",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/ishowspeed_stunned_look_up_77586.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/ishowspeed_stunned_look_up_77586.webp",
    "type": "ANIMATED",
    "category": "REACTION",
    "tags": [
      "ishowspeed",
      "speed",
      "stunned",
      "ballondor",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 150,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:37.983Z"
  },
  {
    "id": "stk_zero_two_anime_dance_loop_ruvwzk",
    "title": "Zero Two Anime Dance Loop",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/zero_two_anime_dance_loop_77983.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/zero_two_anime_dance_loop_77983.webp",
    "type": "ANIMATED",
    "category": "ANIMATED",
    "tags": [
      "zerotwo",
      "anime",
      "dance",
      "phuthon",
      "animated"
    ],
    "isPublic": true,
    "usageCount": 145,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:38.522Z"
  },
  {
    "id": "stk_elon_musk_stream_face_hk04g3",
    "title": "Elon Musk Stream Face",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/elon_musk_stream_face_78522.jpeg",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "elon",
      "musk",
      "gamer",
      "stream",
      "pout",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 140,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:38.971Z"
  },
  {
    "id": "stk_michael_jackson_sequin_glove_3bcddm",
    "title": "Michael Jackson Sequin Glove",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/michael_jackson_sequin_glove_78971.jpeg",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "michaeljackson",
      "mj",
      "legend",
      "glove",
      "kingofpop"
    ],
    "isPublic": true,
    "usageCount": 135,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:39.531Z"
  },
  {
    "id": "stk_happy_clapping_ovation_t2c2fk",
    "title": "Happy Clapping Ovation",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/happy_clapping_ovation_79531.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/happy_clapping_ovation_79531.webp",
    "type": "ANIMATED",
    "category": "REACTION",
    "tags": [
      "clapping",
      "applause",
      "ovation",
      "happy",
      "animated"
    ],
    "isPublic": true,
    "usageCount": 130,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:40.146Z"
  },
  {
    "id": "stk_crying_baby_tantrum_7one36",
    "title": "Crying Baby Tantrum",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/crying_baby_tantrum_80146.webp",
    "type": "STATIC",
    "category": "REACTION",
    "tags": [
      "baby",
      "crying",
      "sobbing",
      "tantrum",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 125,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:40.594Z"
  },
  {
    "id": "stk_spider_man_thumb_point_tcvscq",
    "title": "Spider-Man Thumb Point",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/spider_man_thumb_point_80594.webp",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "spiderman",
      "marvel",
      "thumb",
      "point",
      "hero",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 120,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:41.105Z"
  },
  {
    "id": "stk_pepe_fast_typing_hacker_1d7f0f",
    "title": "Pepe Fast Typing Hacker",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/pepe_fast_typing_hacker_81105.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/pepe_fast_typing_hacker_81105.webp",
    "type": "ANIMATED",
    "category": "ANIMATED",
    "tags": [
      "pepe",
      "typing",
      "keyboard",
      "hacker",
      "coding",
      "animated"
    ],
    "isPublic": true,
    "usageCount": 115,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:41.892Z"
  },
  {
    "id": "stk_robot_sonny_smirk_onxazv",
    "title": "Robot Sonny Smirk",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/robot_sonny_smirk_81892.webp",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "robot",
      "irobot",
      "sonny",
      "smirk",
      "ai",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 110,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:42.578Z"
  },
  {
    "id": "stk_pawpaw_knowing_smirk_q34jem",
    "title": "Pawpaw Knowing Smirk",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/pawpaw_knowing_smirk_82579.webp",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "pawpaw",
      "osita iheme",
      "nollywood",
      "smirk",
      "legend",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 105,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:43.420Z"
  },
  {
    "id": "stk_abuad_100l_compsci_2025_2026_zn49cv",
    "title": "ABUAD 100L CompSci 2025/2026",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/abuad_100l_compsci_2025_2026_83420.webp",
    "type": "STATIC",
    "category": "CAMPUS",
    "tags": [
      "abuad",
      "campus",
      "100level",
      "compsci",
      "class"
    ],
    "isPublic": true,
    "usageCount": 100,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:44.007Z"
  },
  {
    "id": "stk_pepe_teeth_clench_cringe_8lg0x3",
    "title": "Pepe Teeth Clench Cringe",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/pepe_teeth_clench_cringe_84008.webp",
    "type": "STATIC",
    "category": "REACTION",
    "tags": [
      "pepe",
      "teeth",
      "cringe",
      "disgust",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 95,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:44.505Z"
  },
  {
    "id": "stk_subaru_joyful_tears_cry_6sr85j",
    "title": "Subaru Joyful Tears Cry",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/subaru_joyful_tears_cry_84505.webp",
    "type": "STATIC",
    "category": "REACTION",
    "tags": [
      "anime",
      "rezero",
      "subaru",
      "crying",
      "tears",
      "reaction"
    ],
    "isPublic": true,
    "usageCount": 90,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:44.948Z"
  },
  {
    "id": "stk_smiling_dancing_black_cat_yddap2",
    "title": "Smiling Dancing Black Cat",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/smiling_dancing_black_cat_84948.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/smiling_dancing_black_cat_84948.webp",
    "type": "ANIMATED",
    "category": "ANIMATED",
    "tags": [
      "cat",
      "dancing",
      "smiling",
      "happy",
      "animated",
      "cute"
    ],
    "isPublic": true,
    "usageCount": 85,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:45.588Z"
  },
  {
    "id": "stk_tinubu_hand_on_shoulder_comfort_8t9bv1",
    "title": "Tinubu Hand On Shoulder Comfort",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/tinubu_hand_on_shoulder_comfort_85588.webp",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "tinubu",
      "nigeria",
      "comfort",
      "reassurance",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 80,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:46.152Z"
  },
  {
    "id": "stk_gary_coleman_what_chu_talkin_bout_52nyiy",
    "title": "Gary Coleman What'chu Talkin' 'Bout",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/gary_coleman_what_chu_talkin_bout_86153.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/gary_coleman_what_chu_talkin_bout_86153.webp",
    "type": "ANIMATED",
    "category": "MEME",
    "tags": [
      "garycoleman",
      "whatchutalkinbout",
      "classic",
      "diffrentstrokes",
      "animated"
    ],
    "isPublic": true,
    "usageCount": 75,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:46.633Z"
  },
  {
    "id": "stk_laughing_big_teeth_filter_i0vgak",
    "title": "Laughing Big Teeth Filter",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/laughing_big_teeth_filter_86634.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/laughing_big_teeth_filter_86634.webp",
    "type": "ANIMATED",
    "category": "REACTION",
    "tags": [
      "laughing",
      "teeth",
      "filter",
      "lol",
      "reaction",
      "animated"
    ],
    "isPublic": true,
    "usageCount": 70,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:47.045Z"
  },
  {
    "id": "stk_hotdog_looking_around_00nxud",
    "title": "Hotdog Looking Around",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/hotdog_looking_around_87045.webp",
    "animatedUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/hotdog_looking_around_87045.webp",
    "type": "ANIMATED",
    "category": "MEME",
    "tags": [
      "hotdog",
      "looking",
      "funny",
      "animated",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 65,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:47.562Z"
  },
  {
    "id": "stk_contemplating_lone_wolf_rmyap3",
    "title": "Contemplating Lone Wolf",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/contemplating_lone_wolf_87562.webp",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "wolf",
      "lonewolf",
      "thinking",
      "sigma",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 60,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:47.937Z"
  },
  {
    "id": "stk_panda_man_with_cleaver_jnp3ow",
    "title": "Panda Man With Cleaver",
    "imageUrl": "https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/stickers/panda_man_with_cleaver_87937.webp",
    "type": "STATIC",
    "category": "MEME",
    "tags": [
      "panda",
      "pandaman",
      "cleaver",
      "funny",
      "threat",
      "meme"
    ],
    "isPublic": true,
    "usageCount": 55,
    "authorId": "system_curated_stickers",
    "authorName": "ABUAD Campus Stickers",
    "createdAt": "2026-11-06T18:14:48.377Z"
  }
];

// In-memory fallback cache
const localStickersStore: LocalSticker[] = [...DEFAULT_STICKERS];
const localSavedStickers = new Map<string, Set<string>>(); // userId -> Set of stickerIds

/**
 * GET /api/stickers/trending
 * Fetch top trending stickers sorted by usage count
 */
router.get('/trending', optionalAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const limit = parseInt(req.query.limit as string) || 50;

    try {
      const dbStickers = await (prisma as any).sticker.findMany({
        where: { isPublic: true },
        orderBy: { usageCount: 'desc' },
        take: limit,
        include: {
          author: {
            select: { id: true, username: true, fullName: true, avatarUrl: true },
          },
        },
      });

      if (dbStickers && dbStickers.length > 0) {
        return res.json({ success: true, data: dbStickers });
      }
    } catch (_) {
      // Fallback to local store if DB table is unmigrated
    }

    const sorted = [...localStickersStore]
      .filter((s) => s.isPublic)
      .sort((a, b) => b.usageCount - a.usageCount)
      .slice(0, limit);

    return res.json({ success: true, data: sorted });
  } catch (error: any) {
    console.error('Error fetching trending stickers:', error);
    return res.status(500).json({ error: 'Failed to fetch trending stickers' });
  }
});

/**
 * GET /api/stickers/community
 * Browse public community stickers with search and category filtering
 */
router.get('/community', optionalAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const category = (req.query.category as string)?.toUpperCase();
    const search = (req.query.search as string)?.toLowerCase();
    const limit = parseInt(req.query.limit as string) || 150;

    try {
      const where: any = { isPublic: true };
      if (category && category !== 'ALL') {
        where.category = category;
      }
      if (search) {
        where.OR = [
          { title: { contains: search, mode: 'insensitive' } },
          { tags: { has: search } },
        ];
      }

      const dbStickers = await (prisma as any).sticker.findMany({
        where,
        orderBy: [{ usageCount: 'desc' }, { createdAt: 'desc' }],
        take: limit,
        include: {
          author: {
            select: { id: true, username: true, fullName: true, avatarUrl: true },
          },
        },
      });

      if (dbStickers && dbStickers.length > 0) {
        return res.json({ success: true, data: dbStickers });
      }
    } catch (_) {}

    let filtered = localStickersStore.filter((s) => s.isPublic);

    if (category && category !== 'ALL') {
      filtered = filtered.filter((s) => s.category.toUpperCase() === category);
    }

    if (search) {
      filtered = filtered.filter(
        (s) =>
          s.title.toLowerCase().includes(search) ||
          s.tags.some((t) => t.toLowerCase().includes(search))
      );
    }

    return res.json({ success: true, data: filtered.slice(0, limit) });
  } catch (error: any) {
    console.error('Error fetching community stickers:', error);
    return res.status(500).json({ error: 'Failed to fetch community stickers' });
  }
});

/**
 * GET /api/stickers/my
 * Get current user's created and saved stickers
 */
router.get('/my', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;

    try {
      const created = await (prisma as any).sticker.findMany({
        where: { authorId: userId },
        orderBy: { createdAt: 'desc' },
      });

      const savedRecords = await (prisma as any).userSavedSticker.findMany({
        where: { userId },
        include: {
          sticker: {
            include: {
              author: {
                select: { id: true, username: true, fullName: true, avatarUrl: true },
              },
            },
          },
        },
      });

      const saved = savedRecords.map((r: any) => r.sticker);

      return res.json({
        success: true,
        data: {
          created,
          saved,
        },
      });
    } catch (_) {}

    // Fallback store
    const created = localStickersStore.filter((s) => s.authorId === userId);
    const savedIds = localSavedStickers.get(userId) || new Set<string>();
    const saved = localStickersStore.filter((s) => savedIds.has(s.id));

    return res.json({
      success: true,
      data: {
        created,
        saved,
      },
    });
  } catch (error: any) {
    console.error('Error fetching user stickers:', error);
    return res.status(500).json({ error: 'Failed to fetch user stickers' });
  }
});

/**
 * POST /api/stickers
 * Create a new sticker (Drawing, Photo Cutout, or Animated Loop)
 */
router.post('/', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const {
      title,
      imageUrl,
      animatedUrl,
      type = 'STATIC',
      category = 'CAMPUS',
      tags = [],
      isPublic = true,
    } = req.body;

    if (!title || (!imageUrl && !animatedUrl)) {
      return res.status(400).json({ error: 'Title and image or animation are required' });
    }

    const cleanTags = Array.isArray(tags)
      ? tags.map((t: string) => String(t).trim().replace(/^#/, ''))
      : [];

    try {
      const created = await (prisma as any).sticker.create({
        data: {
          title: String(title).trim(),
          imageUrl: String(imageUrl || animatedUrl),
          animatedUrl: animatedUrl ? String(animatedUrl) : null,
          type: String(type).toUpperCase(),
          category: String(category).toUpperCase(),
          tags: cleanTags,
          isPublic: Boolean(isPublic),
          authorId: userId,
        },
        include: {
          author: {
            select: { id: true, username: true, fullName: true, avatarUrl: true },
          },
        },
      });

      return res.status(201).json({ success: true, data: created });
    } catch (_) {}

    // Fallback memory insertion
    const localItem: LocalSticker = {
      id: `stk_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      title: String(title).trim(),
      imageUrl: String(imageUrl || animatedUrl),
      animatedUrl: animatedUrl ? String(animatedUrl) : undefined,
      type: String(type).toUpperCase(),
      category: String(category).toUpperCase(),
      tags: cleanTags,
      isPublic: Boolean(isPublic),
      usageCount: 1,
      authorId: userId,
      authorName: (req.user as any)?.username || (req.user as any)?.name || 'Student',
      createdAt: new Date().toISOString(),
    };

    localStickersStore.unshift(localItem);

    return res.status(201).json({ success: true, data: localItem });
  } catch (error: any) {
    console.error('Error creating sticker:', error);
    return res.status(500).json({ error: 'Failed to create sticker' });
  }
});

/**
 * POST /api/stickers/:id/use
 * Increment sticker usage count (boosts trending score)
 */
router.post('/:id/use', optionalAuth, async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);

    try {
      const updated = await (prisma as any).sticker.update({
        where: { id },
        data: { usageCount: { increment: 1 } },
      });
      return res.json({ success: true, usageCount: updated.usageCount });
    } catch (_) {}

    const local = localStickersStore.find((s) => s.id === id);
    if (local) {
      local.usageCount += 1;
      return res.json({ success: true, usageCount: local.usageCount });
    }

    return res.json({ success: true });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to record sticker usage' });
  }
});

/**
 * POST /api/stickers/:id/save
 * Save sticker to user's favorites tray
 */
router.post('/:id/save', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const stickerId = String(req.params.id);

    try {
      await (prisma as any).userSavedSticker.upsert({
        where: {
          userId_stickerId: { userId, stickerId },
        },
        create: { userId, stickerId },
        update: {},
      });
      return res.json({ success: true, message: 'Sticker saved to collection' });
    } catch (_) {}

    if (!localSavedStickers.has(userId)) {
      localSavedStickers.set(userId, new Set());
    }
    localSavedStickers.get(userId)!.add(stickerId);

    return res.json({ success: true, message: 'Sticker saved to collection' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to save sticker' });
  }
});

/**
 * DELETE /api/stickers/:id/save
 * Remove sticker from user's favorites tray
 */
router.delete('/:id/save', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const stickerId = String(req.params.id);

    try {
      await (prisma as any).userSavedSticker.deleteMany({
        where: { userId, stickerId },
      });
      return res.json({ success: true, message: 'Sticker removed from collection' });
    } catch (_) {}

    localSavedStickers.get(userId)?.delete(stickerId);
    return res.json({ success: true, message: 'Sticker removed from collection' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to remove sticker' });
  }
});

/**
 * DELETE /api/stickers/:id
 * Delete a sticker (author only or admin)
 */
router.delete('/:id', authenticateToken, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.id;
    const userRole = req.user!.role;
    const id = String(req.params.id);

    try {
      const sticker = await (prisma as any).sticker.findUnique({ where: { id } });
      if (!sticker) return res.status(404).json({ error: 'Sticker not found' });

      if (sticker.authorId !== userId && userRole !== 'ADMIN') {
        return res.status(403).json({ error: 'Not authorized to delete this sticker' });
      }

      await (prisma as any).sticker.delete({ where: { id } });
      return res.json({ success: true, message: 'Sticker deleted successfully' });
    } catch (_) {}

    const index = localStickersStore.findIndex((s) => s.id === id);
    if (index !== -1) {
      if (localStickersStore[index].authorId !== userId && userRole !== 'ADMIN') {
        return res.status(403).json({ error: 'Not authorized to delete this sticker' });
      }
      localStickersStore.splice(index, 1);
    }

    return res.json({ success: true, message: 'Sticker deleted successfully' });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to delete sticker' });
  }
});

export default router;

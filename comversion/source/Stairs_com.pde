import java.util.ArrayList;
import java.io.File;
import processing.serial.*;
import processing.sound.*;

// =====================================================
// 【The Stairs最終版】
// Processing (Java mode) - Arduino 完整硬體控制版
// =====================================================

// =====================================================
// Serial
// =====================================================
Serial myPort;
final int SERIAL_BAUD = 115200;
boolean serialReady = false;
final boolean ENABLE_SERIAL = false;  // 電腦版預設關閉 Arduino/Serial

// 若你之後不是 COM3，改這裡即可；找不到時會自動選第一個 port
final String TARGET_PORT_NAME = "COM3";

// 硬體輸入狀態
int hwXState = 0;   // -1 left, 0 neutral, 1 right
int hwYState = 0;   // -1 up,   0 neutral, 1 down
boolean hwPhotoDark = false;

// 最終移動狀態（硬體 / 鍵盤合併）
boolean leftPressed = false;
boolean rightPressed = false;

// 鍵盤輸入狀態（電腦版）
boolean kbLeftPressed = false;
boolean kbRightPressed = false;
boolean kbUpPressed = false;
boolean kbDownPressed = false;
boolean kbShieldHeld = false;

// Intro / Lose / Win 選單
int introMenuIndex = 0;  // 0: Start  1: Exit
int loseMenuIndex = 0;   // 0: Restart Level 1  1: Restart This Level  2: Exit
int winMenuIndex = 0;    // 0: Restart Level 1 1: Exit
int prevMenuYState = 0;

// 字體
PFont uiFont;

// =====================================================
// 畫面
// =====================================================
final int SCREEN_W = 800;
final int SCREEN_H = 600;
float viewScale = 1.0;
float viewOffsetX = 0;
float viewOffsetY = 0;
// =====================================================
// 遊戲狀態
// =====================================================
final int STATE_START = 0;         // 主選單 intro
final int STATE_LEVEL1_INTRO = 1;  // 第一關說明畫面
final int STATE_PLAYING = 2;
final int STATE_LEVEL2_INTRO = 3;
final int STATE_LEVEL3_INTRO = 4;
final int STATE_LOSE = 5;
final int STATE_WIN = 6;
final int STATE_KO = 7;
final int STATE_VICTORY = 8;

int gameState = STATE_START;
int currentLevel = 0;
int loseLevel = 0;

// =====================================================
// 危險來源
// =====================================================
final int HAZARD_BOTTOM = 1;
final int HAZARD_TOP = 2;
final int HAZARD_SPIKE = 3;
final int HAZARD_STONE = 4;

// =====================================================
// 階梯種類
// =====================================================
final int STAIR_SMOOTH = 0;
final int STAIR_SPIKE = 1;
final int STAIR_SLIDE_LEFT = 2;

// =====================================================
// 特殊動畫種類
// =====================================================
final int SPECIAL_NONE = 0;
final int SPECIAL_HIT = 1;
final int SPECIAL_KO = 2;

// =====================================================
// 玩家參數
// =====================================================
final float PLAYER_W = 30;
final float PLAYER_H = 40;
final float PLAYER_SPEED = 5;
final float GRAVITY = 1.1;
final float MAX_FALL_SPEED = 5;

// =====================================================
// 衝刺參數
// =====================================================
final int DASH_FRAMES = 8;
final float DASH_SPEED = PLAYER_SPEED * 2;

// =====================================================
// 世界 / 階梯參數（第四版）
// =====================================================
final float LEVEL1_SCROLL_SPEED = 1.5;
final float LEVEL2_SCROLL_SPEED = 1.6;
final float LEVEL3_SCROLL_SPEED = 1.8;

final float STAIR_W = 130;
final float STAIR_H = 18;
final float STAIR_GAP_Y = 60;
final float SLIDE_LEFT_SPEED = 3;

// Level 1
final float L1_SPIKE_RATIO = 0.40;

// Level 2 / Level 3
final float L23_SPIKE_RATIO = 0.25;
final float L23_SLIDE_RATIO = 0.28;

// Level 2 / 3 平滑階梯中的愛心比例
final float HEART_ON_SMOOTH_RATIO = 0.35;
final float STAR_ON_SMOOTH_RATIO = 0.25;

// =====================================================
// 火球參數（Level 3）
// =====================================================
final float FIREBALL_SIZE = 34;
final float FIREBALL_SPEED = 4.6;
final int FIREBALL_BATCH_INTERVAL = 2000;
final int FIREBALL_BATCH_COUNT = 5;
int lastFireballBatchTime = 0;

// =====================================================
// Level 2 / 3 生命數
// =====================================================
int lives = 3;
final int MAX_LIVES = 3;

// =====================================================
// Level 3 盾牌
// 光敏電阻遮住 2 秒啟動
// =====================================================
boolean shieldSenseActive = false;
int shieldSenseStartTime = -1;
boolean shieldActivationUsed = false;

boolean shieldActive = false;
int shieldCooldownEndTime = 0;
final float SHIELD_OFFSET_Y = -12;
final int SHIELD_HOLD_TIME = 2000;
final int SHIELD_COOLDOWN = 10000;

// =====================================================
// 受傷閃爍 / 短暫無敵
// =====================================================
final int INVINCIBLE_TIME = 1500;

// =====================================================
// 勝利條件
// Level 1 / 2：20 秒
// Level 3：無限時間，蒐集 3 顆星星
// =====================================================
int levelStartTime;
int frozenRemainSeconds = 0;
final int WIN_TIME = 21000;
int starsCollected = 0;
final int MAX_STARS = 5;

// =====================================================
// 物件
// =====================================================
Player player;
ArrayList<Stair> stairs;
ArrayList<Fireball> fireballs;

// =====================================================
// 階梯生成控制
// =====================================================
float spawnAccum = 0;
boolean previousSpawnRowHadSpike = false; //確保不會有連續好幾排的spike出現
// =====================================================
// 素材：背景圖
// /data/background/
// =====================================================
PImage bgIntro;
PImage bgLevel1Intro;
PImage bgLevel1;
PImage bgLevel2Intro;
PImage bgLevel2;
PImage bgLevel3Intro;
PImage bgLevel3;
PImage bgWin;
PImage bgLose;

// =====================================================
// 音效 / 音樂
// /data/sound_effect/
// =====================================================
SoundFile sfxSelect;
SoundFile sfxClick;
SoundFile sfxDash;
SoundFile sfxShield;
SoundFile sfxHeart;
SoundFile sfxDeath1;
SoundFile sfxDeath2;
SoundFile sfxLose;
SoundFile sfxHit;
SoundFile sfxStar;
SoundFile sfxVictory;

SoundFile bgmIntro;
SoundFile bgmLevel1;
SoundFile bgmLevel2;
SoundFile bgmLevel3;
SoundFile bgmWin;

SoundFile currentBgm = null;

final int ACTION_NONE = 0;
final int ACTION_GO_LEVEL_INTRO = 1;
final int ACTION_START_LEVEL = 2;
final int ACTION_GO_WIN = 3;
final int ACTION_GO_LOSE = 4;
final int ACTION_EXIT = 5;

boolean pendingDeathSequence = false;
boolean pendingDeathHasHit = false;
int pendingDeathStage = 0;            // 0: 等待開始, 1: death_1已播, 2: death_2已播完成
int pendingDeathTriggerTime = 0;
int pendingDeathNextTime = 0;

boolean pendingExitApp = false;
int pendingExitTime = 0;
final int EXIT_DELAY_MS = 180;

boolean pendingVictorySequence = false;
int pendingVictoryNextTime = 0;
int pendingVictoryAction = ACTION_NONE;
int pendingVictoryLevel = 0;
boolean victoryAuraActive = false;

boolean transitionLocked = false;
int transitionAction = ACTION_NONE;
int transitionLevel = 0;
int transitionStage = 0;              // 0: 等 click, 1: BGM 已停，準備切畫面
int transitionNextTime = 0;
boolean transitionWithClick = false;
final int TRANSITION_SETTLE_MS = 20;

// =====================================================
// 素材：角色動畫
// =====================================================
PImage[] idleFrames;
PImage[] runFrames;
PImage[] fallFrames;
PImage[] hitFrames;
PImage[] koFrames;

int idleFrameCount = 0;
int runFrameCount = 0;
int fallFrameCount = 0;
int hitFrameCount = 0;
int koFrameCount = 0;

// 顯示大小
final float PLAYER_RENDER_W = 84;
final float PLAYER_RENDER_H = 84;

// 動畫播放速度：數字越大越慢
final int IDLE_FRAME_HOLD = 5;
final int RUN_FRAME_HOLD = 4;
final int FALL_FRAME_HOLD = 4;
final int HIT_FRAME_HOLD = 2;
final int KO_FRAME_HOLD = 2;

// 腳底微調（我測出 idle 用 2 最好）
final float FEET_TUNE_IDLE = 2;
final float FEET_TUNE_RUN = 2;
final float FEET_TUNE_FALL = 2;
final float FEET_TUNE_HIT = 2;
final float FEET_TUNE_KO = 2;

// 左右偏移（暫時都先 0）
final float PLAYER_SPRITE_OFFSET_X = 0;

// =====================================================
// 開機 Loading / 預熱
// =====================================================
boolean bootCompleted = false;
int bootStep = 0;
String bootMessage = "Initializing...";
float bootProgress = 0.0;
float loadingAnimT = 0.0;

int bootWarmupLevel = 1;
int bootWarmupFrame = 0;
final int BOOT_WARMUP_FRAMES_PER_LEVEL = 30;

// =====================================================
void settings() 
{ 
  size(SCREEN_W, SCREEN_H, P2D);
  pixelDensity(displayDensity());
  smooth(4);
}
void setup() {
  frameRate(60);

  surface.setResizable(true);
  updateViewTransform();
  
  uiFont = createFont("Verdana", 32, true);
  textFont(uiFont);

  player = new Player(SCREEN_W / 2 - PLAYER_W / 2, 120);
  stairs = new ArrayList<Stair>();
  fireballs = new ArrayList<Fireball>();

  bootCompleted = false;
  bootStep = 0;
  bootMessage = "Initializing...";
  bootProgress = 0.0;
  loadingAnimT = 0.0;
  bootWarmupLevel = 1;
  bootWarmupFrame = 0;

  background(14, 18, 32);
}

void updateViewTransform() {
  viewScale = min(width / float(SCREEN_W), height / float(SCREEN_H));
  viewOffsetX = (width - SCREEN_W * viewScale) * 0.5;
  viewOffsetY = (height - SCREEN_H * viewScale) * 0.5;
}

void windowResized() {
  updateViewTransform();
}

void connectSerial() {
  if (Serial.list().length == 0) {
    println("No serial port found.");
    serialReady = false;
    return;
  }

  int chosenIndex = -1;

  for (int i = 0; i < Serial.list().length; i++) {
    if (Serial.list()[i].indexOf(TARGET_PORT_NAME) >= 0) {
      chosenIndex = i;
      break;
    }
  }

  if (chosenIndex == -1) {
    chosenIndex = 0;
  }

  try {
    myPort = new Serial(this, Serial.list()[chosenIndex], SERIAL_BAUD);
    myPort.clear();
    myPort.buffer(1);
    serialReady = true;
    println("Connected to: " + Serial.list()[chosenIndex]);
  } catch (Exception e) {
    println("Failed to open serial port.");
    println(e.getMessage());
    serialReady = false;
  }
}

void draw() {
  background(0);

  pushMatrix();
  translate(viewOffsetX, viewOffsetY);
  scale(viewScale);

  drawGameFrame();

  popMatrix();
}

void drawGameFrame() {
  
  if (!bootCompleted) {
    updateBootLoading();
    drawLoadingScreen();
    return;
  }

  updateDeferredActions();
  updatePendingDeathSequence();

  if (gameState == STATE_START) {
    drawStartScreen();
    return;
  }

  if (gameState == STATE_LEVEL1_INTRO) {
    drawLevel1IntroScreen();
    return;
  }

  if (gameState == STATE_LEVEL2_INTRO) {
    drawLevel2IntroScreen();
    return;
  }

  if (gameState == STATE_LEVEL3_INTRO) {
    drawLevel3IntroScreen();
    return;
  }

  if (gameState == STATE_LOSE) {
    drawLoseScreen();
    return;
  }

  if (gameState == STATE_WIN) {
    drawWinScreen();
    return;
  }

  if (gameState == STATE_KO) {
    drawLevelBackground();
    drawStairs();
    drawFireballs();
    player.display();

    if (currentLevel >= 2) {
      drawLivesHUD();
    }
    if (currentLevel == 3) {
      drawStarsHUD();
    }
    drawTimerHUD();

    updateKoSequence();
    return;
  }

  if (gameState == STATE_VICTORY) {
    drawLevelBackground();
    drawStairs();
    drawFireballs();
    player.display();
    if (victoryAuraActive) {
      drawVictoryAura();
    }

    if (currentLevel >= 2) {
      drawLivesHUD();
    }
    if (currentLevel == 3) {
      drawStarsHUD();
    }
    drawTimerHUD();
    return;
  }

  drawLevelBackground();
  updateGame();
  drawStairs();
  drawFireballs();
  player.display();

  if (currentLevel >= 2) {
    drawLivesHUD();
  }
  if (currentLevel == 3) {
    drawStarsHUD();
  }

  drawTimerHUD();

  if (currentLevel == 2) {
    drawLevel2HUD();
  }

  if (currentLevel == 3) {
    drawLevel3HUD();
  }
}

// =====================================================
// Loading / 預熱
// =====================================================

void updateBootLoading() {
  loadingAnimT += 0.10;

  if (bootStep == 0) {
    bootMessage = "Loading player sprites...";
    bootProgress = 0.12;
    loadAllPlayerSprites();
    bootStep++;
    return;
  }

  if (bootStep == 1) {
    bootMessage = "Loading background images...";
    bootProgress = 0.32;
    loadAllBackgroundImages();
    bootStep++;
    return;
  }

  if (bootStep == 2) {
    bootMessage = "Loading sounds...";
    bootProgress = 0.56;
    loadAllSounds();
    bootStep++;
    return;
  }

  if (bootStep == 3) {
    bootProgress = 0.70;

    if (ENABLE_SERIAL) {
      bootMessage = "Connecting Arduino...";
      println("Serial ports:");
      printArray(Serial.list());
      connectSerial();
    } else {
      bootMessage = "Initializing keyboard controls...";
      serialReady = false;
    }

    refreshMovementState();
    bootStep++;
    return;
  }

  if (bootStep == 4) {
    bootMessage = "Pre-warming gameplay...";
    updateBootWarmup();
    return;
  }

  if (bootStep == 5) {
    bootMessage = "Ready";
    bootProgress = 1.0;
    bootCompleted = true;
    returnToStartScreen();
  }
}

void updateBootWarmup() {
  int totalWarmupFrames = BOOT_WARMUP_FRAMES_PER_LEVEL * 3;
  int doneFrames = (bootWarmupLevel - 1) * BOOT_WARMUP_FRAMES_PER_LEVEL + bootWarmupFrame;
  bootProgress = 0.70 + 0.28 * (doneFrames / float(totalWarmupFrames));

  if (bootWarmupLevel > 3) {
    bootProgress = 0.98;
    bootStep = 5;
    return;
  }

  if (bootWarmupFrame == 0) {
    startLevel(bootWarmupLevel);
  }

  drawLevelBackground();
  updateGame();
  drawStairs();
  drawFireballs();
  player.display();

  if (bootWarmupLevel >= 2) {
    drawLivesHUD();
  }
  if (bootWarmupLevel == 3) {
    drawStarsHUD();
  }
  drawTimerHUD();

  bootWarmupFrame++;

  if (bootWarmupFrame >= BOOT_WARMUP_FRAMES_PER_LEVEL) {
    bootWarmupLevel++;
    bootWarmupFrame = 0;
  }

  if (bootWarmupLevel > 3) {
    fireballs.clear();
    stairs.clear();
    bootProgress = 0.98;
    bootStep = 5;
  }
}

void drawLoadingScreen() {
  background(14, 18, 32);

  float titleY = 165;
  float cardY = 320;
  float barW = 360;
  float barH = 18;
  float barX = SCREEN_W / 2 - barW / 2;
  float barY = 365;

  noStroke();
  for (int i = 0; i < 24; i++) {
    float sx = (i * 97 + frameCount * 0.6) % SCREEN_W;
    float sy = 40 + (i * 53) % 210;
    float r = 2 + (i % 3);
    fill(255, 245, 180, 110 + 60 * sin(loadingAnimT + i));
    circle(sx, sy, r);
  }

  float runnerX = SCREEN_W / 2 + sin(loadingAnimT * 1.4) * 90;
  float runnerY = 240 + sin(loadingAnimT * 2.2) * 8;

  fill(255, 255, 255, 18);
  rectMode(CENTER);
  rect(SCREEN_W / 2, cardY, 470, 230, 22);

  fill(245);
  textAlign(CENTER, CENTER);
  textFont(uiFont, 42);
  text("THE STAIRS", SCREEN_W / 2, titleY);

  drawLoadingStairs(SCREEN_W / 2 - 130, 265);
  drawLoadingRunner(runnerX, runnerY);

  textFont(uiFont, 18);
  fill(220);
  text(bootMessage, SCREEN_W / 2, 318);

  fill(255, 255, 255, 35);
  rectMode(CORNER);
  rect(barX, barY, barW, barH, 9);

  fill(255, 225, 120);
  rect(barX, barY, barW * constrain(bootProgress, 0, 1), barH, 9);

  fill(245);
  textFont(uiFont, 16);
  text(int(constrain(bootProgress, 0, 1) * 100) + "%", SCREEN_W / 2, 405);

  String dots = "";
  int dotCount = (frameCount / 18) % 4;
  for (int i = 0; i < dotCount; i++) dots += ".";
  text("Please wait" + dots, SCREEN_W / 2, 438);
}

void drawLoadingStairs(float x, float y) {
  pushStyle();
  rectMode(CORNER);
  noStroke();

  fill(70, 140, 220, 220);
  rect(x + 0, y + 24, 52, 14, 5);
  rect(x + 40, y + 8, 52, 14, 5);
  rect(x + 80, y - 8, 52, 14, 5);
  rect(x + 120, y - 24, 52, 14, 5);

  popStyle();
}

void drawLoadingRunner(float x, float y) {
  pushStyle();
  noStroke();

  fill(255, 190, 110);
  circle(x, y - 26, 18);

  stroke(255, 190, 110);
  strokeWeight(5);
  line(x, y - 16, x, y + 8);
  line(x, y - 5, x - 14, y + 8);
  line(x, y - 3, x + 16, y + 3);
  line(x, y + 8, x - 12, y + 26);
  line(x, y + 8, x + 16, y + 22);

  popStyle();
}

// =====================================================
// 載入背景 / 音效
// =====================================================

void loadAllBackgroundImages() {
  bgIntro = tryLoadImageFromData("background/intro.png");
  bgLevel1Intro = tryLoadImageFromData("background/level1_intro.png");
  bgLevel1 = tryLoadImageFromData("background/level1.png");
  bgLevel2Intro = tryLoadImageFromData("background/level2_intro.png");
  bgLevel2 = tryLoadImageFromData("background/level2.png");
  bgLevel3Intro = tryLoadImageFromData("background/level3_intro.png");
  bgLevel3 = tryLoadImageFromData("background/level3.png"); 
  bgWin = tryLoadImageFromData("background/win.png");
  bgLose = tryLoadImageFromData("background/lose.png");
}

void loadAllSounds() {
  sfxSelect = tryLoadSound("sound_effect/select.wav");
  sfxClick = tryLoadSound("sound_effect/click.wav");
  sfxDash = tryLoadSound("sound_effect/dash.wav");
  sfxShield = tryLoadSound("sound_effect/shield.wav");
  sfxHeart = tryLoadSound("sound_effect/heart.wav");
  sfxDeath1 = tryLoadSound("sound_effect/death_1.wav");
  sfxDeath2 = tryLoadSound("sound_effect/death_2.wav");
  sfxLose = tryLoadSound("sound_effect/lose.wav");
  sfxHit = tryLoadSound("sound_effect/hit.wav");
  sfxStar = tryLoadSound("sound_effect/star.wav");
  sfxVictory = tryLoadSound("sound_effect/victory.wav");

  bgmIntro = tryLoadSound("sound_effect/intro.mp3");
  bgmLevel1 = tryLoadSound("sound_effect/level1.mp3");
  bgmLevel2 = tryLoadSound("sound_effect/level2.mp3");
  bgmLevel3 = tryLoadSound("sound_effect/level3.mp3");
  bgmWin = tryLoadSound("sound_effect/win.mp3");
}

PImage tryLoadImageFromData(String relativePath) {
  if (!fileExistsInData(relativePath)) return null;
  return loadImage(relativePath);
}

SoundFile tryLoadSound(String relativePath) {
  if (!fileExistsInData(relativePath)) {
    println("Missing sound file: " + relativePath);
    return null;
  }

  try {
    return new SoundFile(this, relativePath);
  } catch (Exception e) {
    println("Failed to load sound: " + relativePath);
    println(e.getMessage());
    return null;
  }
}

void drawFullScreenImage(PImage img) {
  if (img == null) return;
  imageMode(CORNER);
  image(img, 0, 0, SCREEN_W, SCREEN_H);
}

void playOneShot(SoundFile sf) {
  if (sf == null) return;
  sf.stop();
  sf.play();
}

void stopSound(SoundFile sf) {
  if (sf == null) return;
  sf.stop();
}

void switchBgm(SoundFile nextBgm) {
  if (currentBgm == nextBgm) return;

  if (currentBgm != null) {
    currentBgm.stop();
  }

  currentBgm = nextBgm;

  if (currentBgm != null) {
    currentBgm.stop();
    currentBgm.loop();
  }
}

void applyScreenAudioForState() {
  if (!bootCompleted) return;

  if (gameState == STATE_START) {
    switchBgm(bgmIntro);
    return;
  }

  if (gameState == STATE_PLAYING) {
    if (currentLevel == 1) {
      switchBgm(bgmLevel1);
    } else if (currentLevel == 2) {
      switchBgm(bgmLevel2);
    } else if (currentLevel == 3) {
      switchBgm(bgmLevel3);
    } else {
      switchBgm(null);
    }
    return;
  }

  if (gameState == STATE_KO || gameState == STATE_VICTORY) {
    switchBgm(null);
    return;
  }

  if (gameState == STATE_WIN) {
    switchBgm(bgmWin);
    return;
  }

  switchBgm(null);

  if (gameState == STATE_LOSE) {
    playOneShot(sfxLose);
  }
}

void setGameState(int newState) {
  if (gameState == newState) {
    applyScreenAudioForState();
    return;
  }

  gameState = newState;
  applyScreenAudioForState();
}

void goToLevelIntro(int level) {
  currentLevel = level;

  if (level == 1) {
    setGameState(STATE_LEVEL1_INTRO);
  } else if (level == 2) {
    setGameState(STATE_LEVEL2_INTRO);
  } else if (level == 3) {
    setGameState(STATE_LEVEL3_INTRO);
  }
}

void requestExitApplication() {
  pendingExitApp = true;
  pendingExitTime = millis() + EXIT_DELAY_MS;
}

void queueTransition(int action, int level, boolean withClick) {
  if (transitionLocked) return;

  transitionLocked = true;
  transitionAction = action;
  transitionLevel = level;
  transitionWithClick = withClick;

  if (withClick) {
    playOneShot(sfxClick);
    transitionStage = 0;
    transitionNextTime = millis() + getSoundDurationMs(sfxClick);
  } else {
    transitionStage = 1;
    transitionNextTime = millis();
  }
}

void clearTransitionLock() {
  transitionLocked = false;
  transitionAction = ACTION_NONE;
  transitionLevel = 0;
  transitionStage = 0;
  transitionNextTime = 0;
  transitionWithClick = false;
}

int getSoundDurationMs(SoundFile sf) {
  if (sf == null) return 0;
  return max(1, int(sf.duration() * 1000));
}

void executeQueuedTransition() {
  int action = transitionAction;
  int level = transitionLevel;
  clearTransitionLock();

  if (action == ACTION_GO_LEVEL_INTRO) {
    goToLevelIntro(level);
  } else if (action == ACTION_START_LEVEL) {
    startLevel(level);
  } else if (action == ACTION_GO_WIN) {
    goToWinScreen();
  } else if (action == ACTION_GO_LOSE) {
    goToLoseScreen();
  } else if (action == ACTION_EXIT) {
    requestExitApplication();
  }
}

void updateDeferredActions() {
  if (transitionLocked && millis() >= transitionNextTime) {
    if (transitionStage == 0) {
      switchBgm(null);
      transitionStage = 1;
      transitionNextTime = millis() + TRANSITION_SETTLE_MS;
    } else if (transitionStage == 1) {
      executeQueuedTransition();
    }
  }

  if (pendingVictorySequence && !transitionLocked && millis() >= pendingVictoryNextTime) {
    int action = pendingVictoryAction;
    int level = pendingVictoryLevel;

    pendingVictorySequence = false;
    pendingVictoryNextTime = 0;
    pendingVictoryAction = ACTION_NONE;
    pendingVictoryLevel = 0;
    victoryAuraActive = false;

    if (action != ACTION_NONE) {
      queueTransition(action, level, false);
    }
  }

  if (pendingExitApp && millis() >= pendingExitTime) {
    stopAllAudio();
    exit();
  }
}

void stopAllAudio() {
  stopSound(sfxSelect);
  stopSound(sfxClick);
  stopSound(sfxDash);
  stopSound(sfxShield);
  stopSound(sfxHeart);
  stopSound(sfxDeath1);
  stopSound(sfxDeath2);
  stopSound(sfxLose);
  stopSound(sfxHit);
  stopSound(sfxStar);
  stopSound(sfxVictory);

  pendingVictorySequence = false;
  pendingVictoryNextTime = 0;
  pendingVictoryAction = ACTION_NONE;
  pendingVictoryLevel = 0;
  victoryAuraActive = false;

  switchBgm(null);
}

void startDeathSequence(boolean playHitFirst) {
  switchBgm(null);
  pendingVictorySequence = false;
  pendingVictoryNextTime = 0;
  pendingVictoryAction = ACTION_NONE;
  pendingVictoryLevel = 0;
  victoryAuraActive = false;

  pendingDeathSequence = true;
  pendingDeathHasHit = playHitFirst;
  pendingDeathStage = 0;
  pendingDeathTriggerTime = millis();

  if (playHitFirst) {
    playOneShot(sfxHit);
    if (sfxHit != null) {
      pendingDeathNextTime = millis() + max(1, int(sfxHit.duration() * 1000));
    } else {
      pendingDeathNextTime = millis();
    }
  } else {
    pendingDeathNextTime = millis();
  }
}

void updatePendingDeathSequence() {
  if (!pendingDeathSequence) return;

  if (pendingDeathStage == 0 && millis() >= pendingDeathNextTime) {
    playOneShot(sfxDeath1);
    if (sfxDeath1 != null) {
      pendingDeathNextTime = millis() + max(1, int(sfxDeath1.duration() * 1000));
    } else {
      pendingDeathNextTime = millis();
    }
    pendingDeathStage = 1;
    return;
  }

  if (pendingDeathStage == 1 && millis() >= pendingDeathNextTime) {
    playOneShot(sfxDeath2);
    if (sfxDeath2 != null) {
      pendingDeathNextTime = millis() + max(1, int(sfxDeath2.duration() * 1000));
    } else {
      pendingDeathNextTime = millis();
    }
    pendingDeathStage = 2;
    return;
  }

  if (pendingDeathStage == 2 && millis() >= pendingDeathNextTime) {
    pendingDeathSequence = false;
    pendingDeathHasHit = false;
    pendingDeathStage = 0;
    pendingDeathTriggerTime = 0;
    pendingDeathNextTime = 0;
  }
}


void startVictorySequence(int nextAction, int nextLevel, boolean withGoldAura) {
  if (gameState == STATE_VICTORY || pendingVictorySequence) return;

  switchBgm(null);

  hwXState = 0;
  hwYState = 0;
  kbShieldHeld = false;
  refreshMovementState();

  pendingVictorySequence = true;
  pendingVictoryNextTime = millis() + getSoundDurationMs(sfxVictory);
  pendingVictoryAction = nextAction;
  pendingVictoryLevel = nextLevel;
  victoryAuraActive = withGoldAura;

  setGameState(STATE_VICTORY);
  playOneShot(sfxVictory);
}

// =====================================================
// 載入角色動畫
// =====================================================
// 載入角色動畫
// =====================================================

void loadAllPlayerSprites() {
  idleFrames = loadSequentialFramesFlexible("idle", "skeleton-01_idle_a_", 0, 19, true);
  idleFrameCount = idleFrames.length;

  runFrames = loadSequentialFramesFlexible("run", "skeleton-03_run_", 0, 12, false);
  runFrameCount = runFrames.length;

  fallFrames = loadSequentialFramesFlexible("fall", "skeleton-05_fall_", 0, 10, false);
  fallFrameCount = fallFrames.length;

  koFrames = loadSequentialFramesFlexible("ko", "skeleton-06_KO_", 0, 30, false);
  koFrameCount = koFrames.length;

  hitFrames = loadSequentialFramesFlexible("hit", "skeleton-08_get_hit_", 0, 5, false);
  hitFrameCount = hitFrames.length;


  println("Loaded idle frames:  " + idleFrameCount);
  println("Loaded run frames:   " + runFrameCount);
  println("Loaded fall frames:  " + fallFrameCount);
  println("Loaded ko frames:    " + koFrameCount);
  println("Loaded hit frames:   " + hitFrameCount);
}

PImage[] loadSequentialFramesFlexible(String subfolder, String baseName, int startIdx, int endIdx, boolean allowRoot) {
  ArrayList<PImage> frames = new ArrayList<PImage>();

  for (int i = startIdx; i <= endIdx; i++) {
    String filename = baseName + nf(i, 2) + ".png";
    PImage img = null;

    if (allowRoot) {
      img = tryLoadSprite("", filename);
    }

    if (img == null) {
      img = tryLoadSprite(subfolder, filename);
    }

    if (img != null) {
      frames.add(img);
    }
  }

  PImage[] arr = new PImage[frames.size()];
  for (int i = 0; i < frames.size(); i++) {
    arr[i] = frames.get(i);
  }
  return arr;
}

PImage tryLoadSprite(String subfolder, String filename) {
  String relativePath;
  if (subfolder == null || subfolder.length() == 0) {
    relativePath = filename;
  } else {
    relativePath = subfolder + "/" + filename;
  }

  if (fileExistsInData(relativePath)) {
    return loadImage(relativePath);
  }

  return null;
}

boolean fileExistsInData(String relativePath) {
  File f = new File(dataPath(relativePath));
  return f.exists() && f.isFile();
}

int loopFrameIndex(int totalFrames, int hold) {
  if (totalFrames <= 0) return 0;
  return (frameCount / hold) % totalFrames;
}

// =====================================================
// Serial packet format (感測器輸入 Sensor Input)
// bit7    = 1
// bit6~5  = X state: 00 neutral, 01 left, 10 right
// bit4~3  = Y state: 00 neutral, 01 up,   10 down
// bit2    = Dash pulse (SW)
// bit1    = Pick pulse (Tilt)
// bit0    = Photo dark
// =====================================================

void serialEvent(Serial p) {
  if (!ENABLE_SERIAL) return;

  while (p.available() > 0) {
    int raw = p.read() & 0xFF;

    if ((raw & 0x80) == 0) continue;

    int xCode = (raw >> 5) & 0x03;
    int yCode = (raw >> 3) & 0x03;

    if (xCode == 1) hwXState = -1;
    else if (xCode == 2) hwXState = 1;
    else hwXState = 0;

    if (yCode == 1) hwYState = -1;
    else if (yCode == 2) hwYState = 1;
    else hwYState = 0;

    boolean dashPulse = (raw & 0x04) != 0;
    boolean pickPulse = (raw & 0x02) != 0;
    hwPhotoDark = (raw & 0x01) != 0;

    refreshMovementState();
    handleMenuNavigation();

    if (dashPulse) {
      handleDashOrSelectInput();
    }

    if (pickPulse) {
      handleTiltInput();
    }
  }
}

void refreshMovementState() {
  if (gameState == STATE_PLAYING) {
    leftPressed = (hwXState == -1) || kbLeftPressed;
    rightPressed = (hwXState == 1) || kbRightPressed;
  } else {
    leftPressed = false;
    rightPressed = false;
  }
}

boolean shieldSenseNow() {
  return hwPhotoDark || kbShieldHeld;
}

// =====================================================
// 鍵盤控制（電腦版）
// C: Pickup / Select
// Z: Dash
// X: Hold to activate shield
// Arrow Up / Down: Menu navigation
// =====================================================

void handleMenuMove(int dir) {
  if (transitionLocked) return;

  boolean moved = false;

  if (gameState == STATE_START) {
    int oldIndex = introMenuIndex;
    introMenuIndex = constrain(introMenuIndex + dir, 0, 1);
    moved = (oldIndex != introMenuIndex);
  } else if (gameState == STATE_LOSE) {
    int oldIndex = loseMenuIndex;
    loseMenuIndex = constrain(loseMenuIndex + dir, 0, 2);
    moved = (oldIndex != loseMenuIndex);
  } else if (gameState == STATE_WIN) {
    int oldIndex = winMenuIndex;
    winMenuIndex = constrain(winMenuIndex + dir, 0, 1);
    moved = (oldIndex != winMenuIndex);
  }

  if (moved) {
    playOneShot(sfxSelect);
  }
}

void handleKeyboardConfirmOrPickupInput() {
  if (transitionLocked) return;

  if (gameState == STATE_START) {
    if (introMenuIndex == 0) {
      queueTransition(ACTION_GO_LEVEL_INTRO, 1, true);
    } else if (introMenuIndex == 1) {
      queueTransition(ACTION_EXIT, 0, true);
    }
    return;
  }

  if (gameState == STATE_LEVEL1_INTRO) {
    queueTransition(ACTION_START_LEVEL, 1, true);
    return;
  }

  if (gameState == STATE_LEVEL2_INTRO) {
    queueTransition(ACTION_START_LEVEL, 2, true);
    return;
  }

  if (gameState == STATE_LEVEL3_INTRO) {
    queueTransition(ACTION_START_LEVEL, 3, true);
    return;
  }

  if (gameState == STATE_LOSE) {
    stopSound(sfxLose);

    if (loseMenuIndex == 0) {
      queueTransition(ACTION_GO_LEVEL_INTRO, loseLevel, true);
    } else if (loseMenuIndex == 1) {
      queueTransition(ACTION_GO_LEVEL_INTRO, 1, true);
    } else if (loseMenuIndex == 2) {
      queueTransition(ACTION_EXIT, 0, true);
    }
    return;
  }

  if (gameState == STATE_WIN) {
    if (winMenuIndex == 0) {
      queueTransition(ACTION_GO_LEVEL_INTRO, 1, true);
    } else if (winMenuIndex == 1) {
      queueTransition(ACTION_EXIT, 0, true);
    }
    return;
  }

  if (gameState == STATE_PLAYING) {
    tryPickCollectibles();
  }
}

void handleKeyboardDashInput() {
  if (transitionLocked) return;

  if (gameState == STATE_PLAYING) {
    if (player.dashFramesLeft <= 0) {
      player.startDash();
      playOneShot(sfxDash);
    }
  }
}

// =====================================================
// SW 的功能：開始 / Dash / 選單確認
// =====================================================

void handleDashOrSelectInput() {
  if (transitionLocked) return;

  if (gameState == STATE_START) {
    if (introMenuIndex == 0) {
      queueTransition(ACTION_GO_LEVEL_INTRO, 1, true);
    } else if (introMenuIndex == 1) {
      queueTransition(ACTION_EXIT, 0, true);
    }
    return;
  }

  if (gameState == STATE_LEVEL1_INTRO) {
    queueTransition(ACTION_START_LEVEL, 1, true);
    return;
  }

  if (gameState == STATE_LEVEL2_INTRO) {
    queueTransition(ACTION_START_LEVEL, 2, true);
    return;
  }

  if (gameState == STATE_LEVEL3_INTRO) {
    queueTransition(ACTION_START_LEVEL, 3, true);
    return;
  }

  if (gameState == STATE_LOSE) {
    stopSound(sfxLose);

    if (loseMenuIndex == 0) {
      queueTransition(ACTION_GO_LEVEL_INTRO, loseLevel, true);
    } else if (loseMenuIndex == 1) {
      queueTransition(ACTION_GO_LEVEL_INTRO, 1, true);
    } else if (loseMenuIndex == 2) {
      queueTransition(ACTION_EXIT, 0, true);
    }
    return;
  }

  if (gameState == STATE_WIN) {
    if (winMenuIndex == 0) {
      queueTransition(ACTION_GO_LEVEL_INTRO, 1, true);
    } else if (winMenuIndex == 1) {
      queueTransition(ACTION_EXIT, 0, true);
    }
    return;
  }

  if (gameState == STATE_PLAYING) {
    if (player.dashFramesLeft <= 0) {
      player.startDash();
      playOneShot(sfxDash);
    }
  }
}

// =====================================================
// =====================================================
// Tilt 的功能：撿愛心
// =====================================================

void handleTiltInput() {
  if (gameState == STATE_PLAYING) {
    tryPickCollectibles();
  }
}

// =====================================================
// Lose / Win 選單上下移動
// =====================================================

void handleMenuNavigation() {
  if (transitionLocked) {
    prevMenuYState = hwYState;
    return;
  }

  if (gameState != STATE_START && gameState != STATE_LOSE && gameState != STATE_WIN) {
    prevMenuYState = hwYState;
    return;
  }

  boolean moved = false;

  if (hwYState == -1 && prevMenuYState != -1) {
    if (gameState == STATE_START) {
      int oldIndex = introMenuIndex;
      introMenuIndex = max(0, introMenuIndex - 1);
      moved = (oldIndex != introMenuIndex);
    } else if (gameState == STATE_LOSE) {
      int oldIndex = loseMenuIndex;
      loseMenuIndex = max(0, loseMenuIndex - 1);
      moved = (oldIndex != loseMenuIndex);
    } else if (gameState == STATE_WIN) {
      int oldIndex = winMenuIndex;
      winMenuIndex = max(0, winMenuIndex - 1);
      moved = (oldIndex != winMenuIndex);
    }
  } else if (hwYState == 1 && prevMenuYState != 1) {
    if (gameState == STATE_START) {
      int oldIndex = introMenuIndex;
      introMenuIndex = min(1, introMenuIndex + 1);
      moved = (oldIndex != introMenuIndex);
    } else if (gameState == STATE_LOSE) {
      int oldIndex = loseMenuIndex;
      loseMenuIndex = min(2, loseMenuIndex + 1);
      moved = (oldIndex != loseMenuIndex);
    } else if (gameState == STATE_WIN) {
      int oldIndex = winMenuIndex;
      winMenuIndex = min(1, winMenuIndex + 1);
      moved = (oldIndex != winMenuIndex);
    }
  }

  if (moved) {
    playOneShot(sfxSelect);
  }

  prevMenuYState = hwYState;
}

// =====================================================
// =====================================================
// 遊戲流程
// =====================================================

void startLevel(int level) {
  currentLevel = level;
  setGameState(STATE_PLAYING);

  hwXState = 0;
  hwYState = 0;
  kbShieldHeld = false;
  refreshMovementState();

  player.resetAll();

  if (currentLevel == 1) {
    lives = 0;
  } else {
    lives = 3;
  }
  starsCollected = 0;

  shieldSenseActive = false;
  shieldSenseStartTime = -1;
  shieldActivationUsed = false;
  shieldActive = false;
  shieldCooldownEndTime = 0;

  pendingVictorySequence = false;
  pendingVictoryNextTime = 0;
  pendingVictoryAction = ACTION_NONE;
  pendingVictoryLevel = 0;
  victoryAuraActive = false;

  spawnAccum = 0;
  fireballs.clear();
  lastFireballBatchTime = millis();
  prevMenuYState = 0;

  levelStartTime = millis();
  frozenRemainSeconds = 0;
  generateInitialWorld();
}

void returnToStartScreen() {
  setGameState(STATE_START);
  currentLevel = 0;
  loseLevel = 0;
  introMenuIndex = 0;
  starsCollected = 0;

  hwXState = 0;
  hwYState = 0;
  kbShieldHeld = false;
  refreshMovementState();

  shieldSenseActive = false;
  shieldSenseStartTime = -1;
  shieldActivationUsed = false;
  shieldActive = false;
  shieldCooldownEndTime = 0;

  pendingVictorySequence = false;
  pendingVictoryNextTime = 0;
  pendingVictoryAction = ACTION_NONE;
  pendingVictoryLevel = 0;
  victoryAuraActive = false;

  fireballs.clear();
  stairs.clear();
  prevMenuYState = 0;
}

void goToLoseScreen() {
  loseLevel = currentLevel;
  loseMenuIndex = 0;
  prevMenuYState = 0;
  victoryAuraActive = false;
  setGameState(STATE_LOSE);
}

void goToWinScreen() {
  winMenuIndex = 0;
  prevMenuYState = 0;
  victoryAuraActive = false;
  setGameState(STATE_WIN);
}

void startKoSequence() {
  if (currentLevel != 3) {
    int elapsed = millis() - levelStartTime;
    frozenRemainSeconds = max(0, (WIN_TIME - elapsed) / 1000);
  }

  player.startKoAnim();
  hwXState = 0;
  hwYState = 0;
  kbShieldHeld = false;
  refreshMovementState();
  setGameState(STATE_KO);
}

void updateKoSequence() {
  if (!transitionLocked && player.isKoAnimFinished() && !pendingDeathSequence) {
    queueTransition(ACTION_GO_LOSE, 0, false);
  }
}

void updateGame() {
  player.updateInvincible();

  if (currentLevel == 3) {
    updateShieldLogic();
    updateFireballSpawner();
  }

  updateStairs();
  player.update();
  handlePlayerStairCollision();
  updateFireballs();
  checkPlayerOutOfBounds();

  if (gameState == STATE_PLAYING && !transitionLocked && !pendingVictorySequence) {
    if (currentLevel == 1 && millis() - levelStartTime >= WIN_TIME) {
      startVictorySequence(ACTION_GO_LEVEL_INTRO, 2, false);
    } else if (currentLevel == 2 && millis() - levelStartTime >= WIN_TIME) {
      startVictorySequence(ACTION_GO_LEVEL_INTRO, 3, false);
    }
  }
}

// =====================================================
// =====================================================
// 各 Level 捲動速度
// =====================================================

float getWorldScrollSpeed() {
  if (currentLevel == 1) return LEVEL1_SCROLL_SPEED;
  if (currentLevel == 2) return LEVEL2_SCROLL_SPEED;
  return LEVEL3_SCROLL_SPEED;
}

// =====================================================
// 背景
// =====================================================

void drawLevelBackground() {
  if (currentLevel == 1 && bgLevel1 != null) {
    drawFullScreenImage(bgLevel1);
    return;
  }

  if (currentLevel == 2 && bgLevel2 != null) {
    drawFullScreenImage(bgLevel2);
    return;
  }

  if (currentLevel == 3 && bgLevel3 != null) {
    drawFullScreenImage(bgLevel3);
    return;
  }

  if (currentLevel == 3) {
    background(18, 22, 48);
    drawStars();
    drawMoon();
  } else {
    background(135, 206, 235);
    drawClouds();
    drawSun();
  }
}

void drawStars() {
  noStroke();
  fill(255, 245, 180);
  for (int i = 0; i < 35; i++) {
    float sx = (i * 97) % SCREEN_W;
    float sy = (i * 53) % 260;
    circle(sx, sy, 3);
  }
}

void drawMoon() {
  noStroke();
  fill(250, 250, 220);
  circle(SCREEN_W - 100, 90, 55);
}

void drawClouds() {
  noStroke();
  fill(255, 255, 255, 190);
  ellipse(130, 85, 90, 40);
  ellipse(165, 85, 70, 32);
  ellipse(520, 120, 115, 45);
  ellipse(565, 120, 80, 35);
}

void drawSun() {
  noStroke();
  fill(255, 220, 90);
  circle(SCREEN_W - 100, 90, 60);
}

// =====================================================
// 畫面：開始 / 轉場 / 失敗 / 勝利
// =====================================================

void drawStartScreen() {
  if (bgIntro != null) {
    drawFullScreenImage(bgIntro);
  } else {
    background(235, 245, 255);
  }

  fill(30);
  drawMenuOption("Start", SCREEN_W / 2, 300, introMenuIndex == 0, color(255));
  drawMenuOption("Exit",  SCREEN_W / 2, 350, introMenuIndex == 1, color(255));
}

void drawLevel1IntroScreen() {
  if (bgLevel1Intro != null) {
    drawFullScreenImage(bgLevel1Intro);
  } else {
    background(235, 245, 255);
  }

  textAlign(CENTER, CENTER);

  textFont(uiFont, 42);
  fill(30);
  text("LEVEL 1", SCREEN_W / 2, 180);

  textFont(uiFont, 22);
  text("Survive For 20 Seconds.", SCREEN_W / 2, 272);
  textFont(uiFont, 17);
  text("Move: Arrow Keys", SCREEN_W / 2, 295);
  text("Dash: Z", SCREEN_W / 2, 315);

  float tw = textWidth("Press C to Start.");
  rectMode(CENTER);
  noStroke();
  fill(255, 245, 180, 200);
  rect(SCREEN_W / 2, 390, tw + 60, 42, 10);
  textFont(uiFont, 20);

  fill(30);
  text("Press C to Start.", SCREEN_W / 2, 390);
}

void drawLevel2IntroScreen() {
  if (bgLevel2Intro != null) {
    drawFullScreenImage(bgLevel2Intro);
  } else {
    background(240, 250, 255);
  }

  textAlign(CENTER, CENTER);

  textFont(uiFont, 42);
  fill(30);
  text("LEVEL 2", SCREEN_W / 2, 170);

  textFont(uiFont, 22);
  text("Keep Your Hearts and Survive.", SCREEN_W / 2, 260);
  textFont(uiFont, 17);
  text("NEW SKILL", SCREEN_W / 2, 298);
  text("Pick Up Hearts: C", SCREEN_W / 2, 323);

  float tw = textWidth("Press C to Start.");
  rectMode(CENTER);
  noStroke();
  fill(255, 245, 180, 200);
  rect(SCREEN_W / 2, 390, tw + 60, 42, 10);
  textFont(uiFont, 20);

  fill(30);
  text("Press C to Start.", SCREEN_W / 2, 390);
}

void drawLevel3IntroScreen() {
  if (bgLevel3Intro != null) {
    drawFullScreenImage(bgLevel3Intro);
  } else {
    background(18, 22, 48);
  }

  textAlign(CENTER, CENTER);

  textFont(uiFont, 42);
  fill(245);
  text("LEVEL 3", SCREEN_W / 2, 173);

  textFont(uiFont, 22);
  text("Now You Have Infinite Time. Try Gather 3 Stars To Win.", SCREEN_W / 2, 245);
  text("Beware of The Falling Fireballs...", SCREEN_W / 2, 270);

  textFont(uiFont, 15);
  text("NEW SKILL", SCREEN_W / 2, 308);
  text("Shield: Hold X For 2 Sec.", SCREEN_W / 2, 330);
  text("Pick Up Items: C", SCREEN_W / 2, 352);
  text("(Items Can Only Be Picked When Shield Is OFF.)", SCREEN_W / 2, 374);

  float tw = textWidth("Press C to Start.");
  rectMode(CENTER);
  noStroke();
  fill(255, 245, 180, 200);
  rect(SCREEN_W / 2, 450, tw + 60, 42, 10);
  textFont(uiFont, 20);

  fill(30);
  text("Press C to Start.", SCREEN_W / 2, 450);
}

void drawLoseScreen() {
  if (bgLose != null) {
    drawFullScreenImage(bgLose);
  } else {
    background(20, 10, 15);
  }

  fill(255, 80, 80);
  textAlign(CENTER, CENTER);
  textFont(uiFont, 44);
  text("YOU LOSEEEE!!!", SCREEN_W / 2, 170);

  drawMenuOption("Restart This Level", SCREEN_W / 2, 280, loseMenuIndex == 0, color(255));
  drawMenuOption("Restart Level 1",    SCREEN_W / 2, 330, loseMenuIndex == 1, color(255));
  drawMenuOption("Exit",               SCREEN_W / 2, 380, loseMenuIndex == 2, color(255));
}

void drawWinScreen() {
  if (bgWin != null) {
    drawFullScreenImage(bgWin);
  } else {
    background(255, 245, 190);
  }

  fill(40, 20, 0);
  textAlign(CENTER, CENTER);
  textFont(uiFont, 34);

  drawMenuOption("Restart to Level 1", SCREEN_W / 2, 300, winMenuIndex == 0, color(255));
  drawMenuOption("Exit",               SCREEN_W / 2, 360, winMenuIndex == 1, color(255));
}

void drawMenuOption(String label, float x, float y, boolean selected, int normalTextColor) {
  pushStyle();
  textAlign(CENTER, CENTER);

  if (selected) {
    textFont(uiFont, 28);
    float tw = textWidth(label);

    rectMode(CENTER);
    noStroke();
    fill(255, 245, 180, 210);
    rect(x, y + 2, tw + 34, 42, 10);

    fill(30);
    text(label, x, y);
  } else {
    textFont(uiFont, 22);
    fill(normalTextColor);
    text(label, x, y);
  }

  popStyle();
}
// =====================================================
// HUD
// =====================================================

void drawTimerHUD() {
  rectMode(CORNER);
  fill(255, 235);
  rect(SCREEN_W - 140, 12, 120, 38, 10);

  fill(20);
  textAlign(CENTER, CENTER);
  textFont(uiFont, 18);

  if (currentLevel == 3) {
    text("∞", SCREEN_W - 80, 31);
    return;
  }

  if (gameState == STATE_KO) {
    text(frozenRemainSeconds + " s", SCREEN_W - 80, 31);
    return;
  }

  int elapsed = millis() - levelStartTime;
  int remain = max(0, (WIN_TIME - elapsed) / 1000);
  text(remain + " s", SCREEN_W - 80, 31);
}

void drawLivesHUD() {
  rectMode(CORNER);
  fill(255, 235);
  rect(10, 10, 155, 44, 10);

  textAlign(LEFT, CENTER);
  textFont(uiFont, 18);
  fill(20);
  text("Lives:", 20, 32);

  for (int i = 0; i < MAX_LIVES; i++) {
    float hx = 90 + i * 24;
    float hy = 32;

    if (i < lives) {
      drawHeart(hx, hy, 14, color(235, 70, 90));
    } else {
      drawHeart(hx, hy, 14, color(180, 180, 180));
    }
  }
}


void drawStarsHUD() {
  rectMode(CORNER);
  fill(255, 235);
  rect(10, 62, 200, 44, 10);

  textAlign(LEFT, CENTER);
  textFont(uiFont, 18);
  fill(20);
  text("Stars:", 20, 84);

  for (int i = 0; i < MAX_STARS; i++) {
    float sx = 96 + i * 22;
    float sy = 84;

    if (i < starsCollected) {
      drawStar(sx, sy, 7, color(255, 215, 80), color(255, 240, 170));
    } else {
      drawStar(sx, sy, 7, color(180, 180, 180), color(220, 220, 220));
    }
  }
}

void drawLevel2HUD() {
  fill(120);
  textAlign(LEFT, CENTER);
  textFont(uiFont, 14);
  text("Level 2: Press C to pick up hearts", 20, 79);
}

void drawLevel3HUD() {
  
  fill(255);
  textAlign(LEFT, TOP);
  textFont(uiFont, 14);

  if (shieldActive) {
    text("Shield: ACTIVE", 20, 124);
    text("Pickup disabled while shield is active", 20, 146);
  } else {
    int cd = max(0, shieldCooldownEndTime - millis());
    if (cd > 0) {
      text("Shield cooldown: " + nf(cd / 1000.0, 1, 1) + " s", 20, 124);
    } else {
      text("Hold X for 2 sec to shield", 20, 124);

      if (shieldSenseNow() && shieldSenseStartTime != -1) {
        float holdSec = (millis() - shieldSenseStartTime) / 1000.0;
        holdSec = min(holdSec, 2.0);
        text("Time Accumulated: " + nf(holdSec, 1, 3) + " / 2.000s", 20, 166);
      }
    }
    text("Press C to pick up hearts / stars", 20, 146);
  }
}

void drawHeart(float x, float y, float size, color c) {
  pushMatrix();
  pushStyle();
  translate(x, y);
  noStroke();
  fill(c);
  ellipse(-size * 0.35, -size * 0.20, size * 0.75, size * 0.75);
  ellipse(size * 0.35, -size * 0.20, size * 0.75, size * 0.75);
  triangle(-size * 0.80, 0, size * 0.80, 0, 0, size * 1.1);
  popStyle();
  popMatrix();
}


void drawStar(float x, float y, float rOuter, color fillColor, color strokeColor) {
  pushMatrix();
  pushStyle();
  translate(x, y);
  fill(fillColor);
  stroke(strokeColor);
  strokeWeight(1.5);
  beginShape();
  for (int i = 0; i < 10; i++) {
    float ang = -HALF_PI + i * PI / 5.0;
    float r = (i % 2 == 0) ? rOuter : rOuter * 0.45;
    vertex(cos(ang) * r, sin(ang) * r);
  }
  endShape(CLOSE);
  popStyle();
  popMatrix();
}

void drawVictoryAura() {
  float auraX = player.x + player.w / 2;
  float auraY = player.y + player.h / 2 + SHIELD_OFFSET_Y;

  pushStyle();
  noFill();
  stroke(255, 220, 90, 220);
  strokeWeight(4);
  ellipse(auraX, auraY, 60, 70);

  stroke(255, 245, 180, 150);
  strokeWeight(2);
  ellipse(auraX, auraY, 68, 78);
  popStyle();
}

// =====================================================
// Shield
// =====================================================

void updateShieldLogic() {
  shieldSenseActive = shieldSenseNow();

  if (!shieldSenseActive) {
    shieldSenseStartTime = -1;
    shieldActivationUsed = false;
    return;
  }

  if (shieldActive) return;

  if (millis() < shieldCooldownEndTime) {
    shieldSenseStartTime = millis();
    return;
  }

  if (shieldSenseStartTime == -1) {
    shieldSenseStartTime = millis();
  }

  if (!shieldActivationUsed && millis() - shieldSenseStartTime >= SHIELD_HOLD_TIME) {
    shieldActive = true;
    shieldActivationUsed = true;
    playOneShot(sfxShield);
  }
}

void breakShield() {
  shieldActive = false;
  shieldCooldownEndTime = millis() + SHIELD_COOLDOWN;
}

// =====================================================
// Fireballs
// =====================================================

void updateFireballSpawner() {
  if (millis() - lastFireballBatchTime >= FIREBALL_BATCH_INTERVAL) {
    for (int i = 0; i < FIREBALL_BATCH_COUNT; i++) {
      float fx = random(0, SCREEN_W - FIREBALL_SIZE);
      float fy = -random(20, 140);
      fireballs.add(new Fireball(fx, fy));
    }
    lastFireballBatchTime = millis();
  }
}

void updateFireballs() {
  for (int i = fireballs.size() - 1; i >= 0; i--) {
    Fireball f = fireballs.get(i);
    f.update();

    if (rectOverlap(f.x, f.y, f.size, f.size, player.x, player.y, player.w, player.h)) {
      fireballs.remove(i);

      if (!player.invincible) {
        applyAttackDamage(HAZARD_STONE);
      }
      return;
    }

    if (f.y > SCREEN_H + 20) {
      fireballs.remove(i);
    }
  }
}

void drawFireballs() {
  for (Fireball f : fireballs) {
    f.display();
  }
}

// =====================================================
// 世界 / 階梯
// =====================================================

void generateInitialWorld() {
  stairs.clear();
  fireballs.clear();
  spawnAccum = 0;
  previousSpawnRowHadSpike = false;
  
  if (currentLevel == 3) {
    lastFireballBatchTime = millis();
  }

  float startStairX = SCREEN_W / 2 - STAIR_W / 2;
  float startStairY = 280;

  Stair startStair = new Stair(startStairX, startStairY, STAIR_SMOOTH, false, false);
  stairs.add(startStair);

  player.x = startStairX + STAIR_W / 2 - player.w / 2;
  player.y = startStairY - player.h;
  player.prevY = player.y;
  player.vy = 0;
  player.onStair = true;
  player.supportType = STAIR_SMOOTH;
  player.dashFramesLeft = 0;

  for (float y = SCREEN_H - 40; y >= -20; y -= STAIR_GAP_Y) {
    if (abs(y - startStairY) > 5) {
      spawnStairRow(y);
    }
  }
}

void updateStairs() {
  float scrollSpeed = getWorldScrollSpeed();

  for (int i = stairs.size() - 1; i >= 0; i--) {
    Stair s = stairs.get(i);
    s.y -= scrollSpeed;

    if (s.y + s.h < 0) {
      stairs.remove(i);
    }
  }

  spawnAccum += scrollSpeed;
  if (spawnAccum >= STAIR_GAP_Y) {
    spawnAccum = 0;
    spawnStairRow(height + 20);
  }
}

void spawnStairRow(float y) {
  int num = (random(1) < 0.35) ? 2 : 1;

  boolean allowSpikeThisRow = !previousSpawnRowHadSpike;
  boolean rowHasSpike = false;

  Stair s1 = createStairForCurrentLevel(
    random(20, width - STAIR_W - 20),
    y,
    allowSpikeThisRow
  );
  stairs.add(s1);

  if (s1.type == STAIR_SPIKE) {
    rowHasSpike = true;
  }

  if (num == 2) {
    float x2 = random(20, width - STAIR_W - 20);
    int safeGuard = 0;
    while (abs(x2 - s1.x) < STAIR_W * 0.75 && safeGuard < 20) {
      x2 = random(20, width - STAIR_W - 20);
      safeGuard++;
    }

    Stair s2 = createStairForCurrentLevel(x2, y, allowSpikeThisRow);
    stairs.add(s2);

    if (s2.type == STAIR_SPIKE) {
      rowHasSpike = true;
    }
  }

  previousSpawnRowHadSpike = rowHasSpike;
}

Stair createStairForCurrentLevel(float x, float y, boolean allowSpikeThisRow) {
  if (currentLevel == 1) {
    int type;

    if (allowSpikeThisRow && random(1) < L1_SPIKE_RATIO) {
      type = STAIR_SPIKE;
    } else {
      type = STAIR_SMOOTH;
    }

    return new Stair(x, y, type, false, false);
  } else {
    int type;

    if (allowSpikeThisRow) {
      float r = random(1);

      if (r < L23_SPIKE_RATIO) {
        type = STAIR_SPIKE;
      } else if (r < L23_SPIKE_RATIO + L23_SLIDE_RATIO) {
        type = STAIR_SLIDE_LEFT;
      } else {
        type = STAIR_SMOOTH;
      }
    } else {
      // 這一排禁止尖刺，只能是 smooth 或 slide
      float nonSpikeSlideRatio = L23_SLIDE_RATIO / (1.0 - L23_SPIKE_RATIO);
      float r = random(1);

      if (r < nonSpikeSlideRatio) {
        type = STAIR_SLIDE_LEFT;
      } else {
        type = STAIR_SMOOTH;
      }
    }

    boolean placeHeart = false;
    boolean placeStar = false;

    if (type == STAIR_SMOOTH) {
      if (currentLevel == 2) {
        placeHeart = random(1) < HEART_ON_SMOOTH_RATIO;
      } else if (currentLevel == 3) {
        placeHeart = random(1) < HEART_ON_SMOOTH_RATIO;
        placeStar = random(1) < STAR_ON_SMOOTH_RATIO;
      }
    }

    return new Stair(x, y, type, placeHeart, placeStar);
  }
}

void drawStairs() {
  for (Stair s : stairs) {
    s.display();
  }
}

// =====================================================
// 玩家與階梯碰撞
// =====================================================

void handlePlayerStairCollision() {
  Stair bestSupport = null;
  float bestDist = 999999;

  float feet = player.y + player.h;
  float prevFeet = player.prevY + player.h;

  for (Stair s : stairs) {
    boolean overlapX = (player.x + player.w > s.x + 6) &&
      (player.x < s.x + s.w - 6);

    boolean nearTopNow = (feet >= s.y - 12) &&
      (feet <= s.y + s.h + 8);

    boolean wasAboveOrNearTop = (prevFeet <= s.y + 14);

    if (overlapX && nearTopNow && wasAboveOrNearTop) {
      float dist = abs(feet - s.y);
      if (dist < bestDist) {
        bestDist = dist;
        bestSupport = s;
      }
    }
  }

  if (bestSupport != null) {
    if (bestSupport.type == STAIR_SPIKE) {
      player.onStair = false;
      player.supportType = STAIR_SMOOTH;

      if (!player.invincible) {
        applyAttackDamage(HAZARD_SPIKE);
      }
      return;
    }

    player.y = bestSupport.y - player.h;
    player.vy = 0;
    player.onStair = true;
    player.supportType = bestSupport.type;
  } else {
    player.onStair = false;
    player.supportType = STAIR_SMOOTH;
  }
}

// =====================================================
// 出界判定：直接輸
// =====================================================

void checkPlayerOutOfBounds() {
  if (player.y > SCREEN_H) {
    startDeathSequence(false);
    startKoSequence();
    return;
  }

  if (player.onStair && player.y < 0) {
    startDeathSequence(false);
    startKoSequence();
    return;
  }
}

// =====================================================
// =====================================================
// 受傷邏輯
// Level 3 有盾時：被尖刺 / 火球打到只耗盾，不扣血
// =====================================================

void applyAttackDamage(int hazardType) {
  if (player.invincible) return;

  boolean hitTriggered = (hazardType == HAZARD_SPIKE || hazardType == HAZARD_STONE);

  // Level 1：踩到尖刺直接 KO
  if (currentLevel == 1) {
    if (hitTriggered) {
      startDeathSequence(true);
    } else {
      startDeathSequence(false);
    }
    startKoSequence();
    return;
  }

  // Level 3：有盾 -> 只耗盾、不扣血
  if (currentLevel == 3 && shieldActive) {
    if (hitTriggered) {
      playOneShot(sfxHit);
    }

    breakShield();
    player.startInvincible();

    if (hazardType == HAZARD_SPIKE) {
      player.onStair = false;
      player.vy = -2.0;
      player.y -= 8;
    } else if (hazardType == HAZARD_STONE) {
      player.vy = -1.5;
    }
    return;
  }

  // Level 2 / 3：最後一滴血被尖刺或火球打到 -> KO 動畫 -> Lose
  if (lives <= 1) {
    lives = 0;
    if (hitTriggered) {
      startDeathSequence(true);
    } else {
      startDeathSequence(false);
    }
    startKoSequence();
    return;
  }

  // 還有命：扣一滴，觸發 hit
  lives--;
  if (hitTriggered) {
    playOneShot(sfxHit);
  }
  player.startInvincible();
  player.startHitAnim();

  if (hazardType == HAZARD_SPIKE) {
    player.onStair = false;
    player.vy = -2.0;
    player.y -= 8;
  } else if (hazardType == HAZARD_STONE) {
    player.vy = -1.5;
  }
}

// =====================================================
// 撿愛心、星星
// =====================================================

void tryPickCollectibles() {
  if (currentLevel != 2 && currentLevel != 3) return;
  if (currentLevel == 3 && shieldActive) return;

  for (Stair s : stairs) {
    if (s.hasHeart && lives < MAX_LIVES) {
      float hx = s.x + s.heartOffsetX;
      float hy = s.y - 14;

      boolean overlapHeart = (hx >= player.x - 8 && hx <= player.x + player.w + 8 &&
        hy >= player.y - 8 && hy <= player.y + player.h + 8);

      if (overlapHeart) {
        lives = min(MAX_LIVES, lives + 1);
        s.hasHeart = false;
        playOneShot(sfxHeart);
        return;
      }
    }

    if (currentLevel == 3 && s.hasStar) {
      float sx = s.x + s.starOffsetX;
      float sy = s.y - 14;

      boolean overlapStar = (sx >= player.x - 12 && sx <= player.x + player.w + 12 &&
        sy >= player.y - 8 && sy <= player.y + player.h + 8);

      if (overlapStar) {
        starsCollected = min(MAX_STARS, starsCollected + 1);
        s.hasStar = false;
        playOneShot(sfxStar);

        if (starsCollected >= MAX_STARS && gameState == STATE_PLAYING && !transitionLocked && !pendingVictorySequence) {
          startVictorySequence(ACTION_GO_WIN, 0, true);
        }
        return;
      }
    }
  }
}

// =====================================================
// 鍵盤控制（電腦版）
// Left / Right: 移動
// Up / Down: 選單移動
// Z: Dash
// X: Shield（長按 2 秒）
// C: Pickup / Select
// =====================================================

void keyPressed() {
  if (key == CODED) {
    if (keyCode == LEFT) {
      kbLeftPressed = true;
      refreshMovementState();
    } else if (keyCode == RIGHT) {
      kbRightPressed = true;
      refreshMovementState();
    } else if (keyCode == UP) {
      if (!kbUpPressed) {
        kbUpPressed = true;
        handleMenuMove(-1);
      }
    } else if (keyCode == DOWN) {
      if (!kbDownPressed) {
        kbDownPressed = true;
        handleMenuMove(1);
      }
    }
    return;
  }

  char k = Character.toLowerCase(key);

  if (k == 'z') {
    handleKeyboardDashInput();
  } else if (k == 'x') {
    kbShieldHeld = true;
  } else if (k == 'c') {
    handleKeyboardConfirmOrPickupInput();
  }

  refreshMovementState();
}

void keyReleased() {
  if (key == CODED) {
    if (keyCode == LEFT) {
      kbLeftPressed = false;
    } else if (keyCode == RIGHT) {
      kbRightPressed = false;
    } else if (keyCode == UP) {
      kbUpPressed = false;
    } else if (keyCode == DOWN) {
      kbDownPressed = false;
    }

    refreshMovementState();
    return;
  }

  char k = Character.toLowerCase(key);

  if (k == 'x') {
    kbShieldHeld = false;
  }

  refreshMovementState();
}

// =====================================================
// 工具函式
// =====================================================

boolean rectOverlap(float x1, float y1, float w1, float h1,
  float x2, float y2, float w2, float h2) {
  return x1 < x2 + w2 &&
    x1 + w1 > x2 &&
    y1 < y2 + h2 &&
    y1 + h1 > y2;
}

// =====================================================
// 類別：Player
// =====================================================

class Player {
  float x, y;
  float prevY;
  float w, h;

  float vy = 0;
  float lastMoveX = 0;

  int facing = 1;
  boolean onStair = false;
  int supportType = STAIR_SMOOTH;

  int dashFramesLeft = 0;
  int dashDir = 1;

  boolean invincible = false;
  int invincibleEndTime = 0;

  int specialAnim = SPECIAL_NONE;
  int specialAnimStartFrame = 0;

  Player(float x, float y) {
    this.x = x;
    this.y = y;
    this.w = PLAYER_W;
    this.h = PLAYER_H;
    this.prevY = y;
  }

  void resetAll() {
    x = SCREEN_W / 2 - w / 2;
    y = 120;
    prevY = y;
    vy = 0;
    lastMoveX = 0;
    facing = 1;
    onStair = false;
    supportType = STAIR_SMOOTH;
    dashFramesLeft = 0;
    dashDir = 1;
    invincible = false;
    invincibleEndTime = 0;
    specialAnim = SPECIAL_NONE;
    specialAnimStartFrame = 0;
  }

  void startInvincible() {
    invincible = true;
    invincibleEndTime = millis() + INVINCIBLE_TIME;
  }

  void updateInvincible() {
    if (invincible && millis() >= invincibleEndTime) {
      invincible = false;
    }
  }

  void startDash() {
    if (dashFramesLeft > 0) return;
    dashDir = facing;
    dashFramesLeft = DASH_FRAMES;
  }

  void startHitAnim() {
    specialAnim = SPECIAL_HIT;
    specialAnimStartFrame = frameCount;
  }

  void startKoAnim() {
    specialAnim = SPECIAL_KO;
    specialAnimStartFrame = frameCount;
  }

  boolean isKoAnimFinished() {
    if (specialAnim != SPECIAL_KO) return true;
    if (koFrameCount == 0) return true;

    int idx = (frameCount - specialAnimStartFrame) / KO_FRAME_HOLD;
    return idx >= koFrameCount;
  }

  void update() {
    prevY = y;

    float moveX = 0;
    float scrollSpeed = getWorldScrollSpeed();

    if (leftPressed && !rightPressed) facing = -1;
    if (rightPressed && !leftPressed) facing = 1;

    if (dashFramesLeft > 0) {
      moveX = DASH_SPEED * dashDir;
      dashFramesLeft--;
    } else {
      if (onStair && supportType == STAIR_SLIDE_LEFT) {
        moveX -= SLIDE_LEFT_SPEED;
      }

      if (leftPressed) moveX -= PLAYER_SPEED;
      if (rightPressed) moveX += PLAYER_SPEED;
    }

    lastMoveX = moveX;

    x += moveX;
    x = constrain(x, 0, SCREEN_W - w);

    if (onStair) {
      y -= scrollSpeed;
      vy = 0;
    } else {
      vy += GRAVITY;
      vy = min(vy, MAX_FALL_SPEED);
      y += vy;
    }
  }

  void display() {
   /* boolean visible = true;
    if (invincible && specialAnim != SPECIAL_KO) {
      visible = ((millis() / 120) % 2 == 0);
    }

    if (!visible) return; */

    pushStyle();

    // dash 殘影
    if (dashFramesLeft > 0) {
      fill(220, 220, 250, 110);
      noStroke();
      for (int i = 1; i <= 3; i++) {
        rectMode(CORNER);
        rect(x - dashDir * i * 12, y - 4, w - 4, h - 8, 6);
      }
    }

    // 選擇目前要顯示的圖片
    PImage currentImg = null;
    float currentFeetTune = FEET_TUNE_IDLE;

    // 1) KO
    if (specialAnim == SPECIAL_KO && koFrameCount > 0) {
      int idx = min((frameCount - specialAnimStartFrame) / KO_FRAME_HOLD, koFrameCount - 1);
      currentImg = koFrames[idx];
      currentFeetTune = FEET_TUNE_KO;
    }
    

    // 2) HIT
    if (currentImg == null && specialAnim == SPECIAL_HIT && hitFrameCount > 0) {
      int idx = (frameCount - specialAnimStartFrame) / HIT_FRAME_HOLD;
      if (idx < hitFrameCount) {
        currentImg = hitFrames[idx];
        currentFeetTune = FEET_TUNE_HIT;
      } else {
        specialAnim = SPECIAL_NONE;
      }
    }

    // 3) FALL
    if (currentImg == null && !onStair && fallFrameCount > 0) {
      int idx = loopFrameIndex(fallFrameCount, FALL_FRAME_HOLD);
      currentImg = fallFrames[idx];
      currentFeetTune = FEET_TUNE_FALL;
    }

    // 4) RUN
    if (currentImg == null && onStair && abs(lastMoveX) > 0.1 && runFrameCount > 0) {
      int idx = loopFrameIndex(runFrameCount, RUN_FRAME_HOLD);
      currentImg = runFrames[idx];
      currentFeetTune = FEET_TUNE_RUN;
    }

    // 5) IDLE
    if (currentImg == null && idleFrameCount > 0) {
      int idx = loopFrameIndex(idleFrameCount, IDLE_FRAME_HOLD);
      currentImg = idleFrames[idx];
      currentFeetTune = FEET_TUNE_IDLE;
    }

    // 若有載入圖片，優先用圖片
    if (currentImg != null) {
      pushMatrix();
      imageMode(CENTER);

      float footX = x + w / 2 + PLAYER_SPRITE_OFFSET_X;
      float footY = y + h;

      float spriteCenterX = footX;
      float spriteCenterY = footY - PLAYER_RENDER_H / 2 - currentFeetTune;

      translate(spriteCenterX, spriteCenterY);

      if (facing == -1) {
        scale(-1, 1);
      }

      image(currentImg, 0, 0, PLAYER_RENDER_W, PLAYER_RENDER_H);
      popMatrix();
    } else {
      // fallback：沒有圖片時用方塊
      if (dashFramesLeft > 0) {
        fill(255, 150, 80);
      } else {
        fill(255, 110, 110);
      }

      stroke(30);
      strokeWeight(2);
      rectMode(CORNER);
      rect(x, y, w, h, 8);

      fill(255);
      noStroke();
      if (facing == 1) {
        circle(x + 20, y + 12, 6);
      } else {
        circle(x + 10, y + 12, 6);
      }
    }

    // 防護罩
    if (currentLevel == 3 && shieldActive) {
      float shieldX = x + w / 2;
      float shieldY = y + h / 2 + SHIELD_OFFSET_Y;
    
      noFill();
      stroke(120, 220, 255, 180);
      strokeWeight(4);
      ellipse(shieldX, shieldY, 56, 66);
    
      stroke(180, 240, 255, 120);
      strokeWeight(2);
      ellipse(shieldX, shieldY, 62, 72);
    }

    popStyle();
  }
}

// =====================================================
// 類別：Stair
// =====================================================

class Stair {
  float x, y;
  float w, h;
  int type;

  boolean hasHeart = false;
  float heartOffsetX = 0;
  boolean hasStar = false;
  float starOffsetX = 0;

  Stair(float x, float y, int type, boolean hasHeart, boolean hasStar) {
    this.x = x;
    this.y = y;
    this.w = STAIR_W;
    this.h = STAIR_H;
    this.type = type;
    this.hasHeart = hasHeart;
    this.hasStar = hasStar;

    if (hasHeart) {
      heartOffsetX = random(22, w - 22);
    }
    if (hasStar) {
      starOffsetX = random(22, w - 22);
      int guard = 0;
      while (hasHeart && abs(starOffsetX - heartOffsetX) < 22 && guard < 20) {
        starOffsetX = random(22, w - 22);
        guard++;
      }
    }
  }

  void display() {
    pushStyle();

    if (type == STAIR_SMOOTH) {
      fill(90, 190, 120);
      stroke(40, 120, 60);
      strokeWeight(2);
      rectMode(CORNER);
      rect(x, y, w, h, 5);

      stroke(255, 255, 255, 80);
      line(x + 8, y + 5, x + w - 8, y + 5);
    } else if (type == STAIR_SPIKE) {
      fill(140, 80, 170);
      stroke(70, 30, 90);
      strokeWeight(2);
      rectMode(CORNER);
      rect(x, y, w, h, 5);

      fill(230);
      noStroke();
      int spikes = 8;
      float spikeW = w / spikes;
      for (int i = 0; i < spikes; i++) {
        triangle(
          x + i * spikeW, y,
          x + i * spikeW + spikeW / 2, y - 10,
          x + (i + 1) * spikeW, y
        );
      }
    } else if (type == STAIR_SLIDE_LEFT) {
      fill(80, 170, 230);
      stroke(35, 90, 150);
      strokeWeight(2);
      rectMode(CORNER);
      rect(x, y, w, h, 5);

      stroke(255, 255, 255, 180);
      strokeWeight(2);
      for (int i = 0; i < 3; i++) {
        float ax = x + 28 + i * 26;
        float ay = y + h / 2;
        line(ax + 8, ay - 5, ax - 4, ay);
        line(ax + 8, ay + 5, ax - 4, ay);
      }
    }

    if (hasHeart) {
      drawHeart(x + heartOffsetX, y - 14, 12, color(235, 70, 90));
    }
    if (hasStar) {
      drawStar(x + starOffsetX, y - 14, 8, color(255, 215, 80), color(255, 240, 170));
    }

    popStyle();
  }
}

// =====================================================
// 類別：Fireball
// =====================================================

class Fireball {
  float x, y;
  float size;

  Fireball(float x, float y) {
    this.x = x;
    this.y = y;
    this.size = FIREBALL_SIZE;
  }

  void update() {
    y += FIREBALL_SPEED;
  }

  void display() {
    pushStyle();

    noStroke();
    fill(255, 70, 30, 220);
    ellipse(x + size / 2, y + size / 2, size, size);

    fill(255, 150, 40, 220);
    ellipse(x + size / 2, y + size / 2, size * 0.65, size * 0.65);

    fill(255, 230, 120, 200);
    ellipse(x + size / 2, y + size / 2, size * 0.30, size * 0.30);

    popStyle();
  }
}

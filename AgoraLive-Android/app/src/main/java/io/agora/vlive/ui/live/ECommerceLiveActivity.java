package io.agora.vlive.ui.live;

import android.os.Bundle;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.RelativeLayout;

import io.agora.rtc.Constants;
import io.agora.vlive.R;
import io.agora.vlive.ui.actionsheets.LiveRoomToolActionSheet;
import io.agora.vlive.ui.components.CameraTextureView;
import io.agora.vlive.ui.components.LiveBottomButtonLayout;
import io.agora.vlive.ui.components.LiveHostNameLayout;
import io.agora.vlive.ui.components.LiveMessageEditLayout;

public class ECommerceLiveActivity extends LiveRoomActivity implements View.OnClickListener {
    private static final String TAG = SingleHostLiveActivity.class.getSimpleName();

    private LiveHostNameLayout mNamePad;
    private FrameLayout mVideoLayout;
    private boolean mTopLayoutCalculated;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        hideStatusBar(false);
    }

    @Override
    protected void onPermissionGranted() {
        initUI();
        super.onPermissionGranted();
    }

    private void initUI() {
        setContentView(R.layout.activity_single_host);

        mNamePad = findViewById(R.id.single_live_name_pad);
        mNamePad.init();

        participants = findViewById(R.id.single_live_participant);
        participants.init();
        participants.setUserLayoutListener(this);

        bottomButtons = findViewById(R.id.single_live_bottom_layout);
        bottomButtons.init();
        bottomButtons.setLiveBottomButtonListener(this);
        bottomButtons.setRole(isOwner ? LiveBottomButtonLayout.ROLE_OWNER :
                isHost ? LiveBottomButtonLayout.ROLE_HOST :
                        LiveBottomButtonLayout.ROLE_AUDIENCE);
        if (isOwner || isHost) {
            bottomButtons.setBeautyEnabled(config().isBeautyEnabled());
        }

        mVideoLayout = findViewById(R.id.single_live_video_layout);

        if (isOwner) {
            becomesOwner(false, false);
        }

        findViewById(R.id.live_bottom_btn_close).setOnClickListener(this);
        findViewById(R.id.live_bottom_btn_more).setOnClickListener(this);
        findViewById(R.id.live_bottom_btn_fun1).setOnClickListener(this);
        findViewById(R.id.live_bottom_btn_fun2).setOnClickListener(this);

        messageList = findViewById(R.id.message_list);
        messageList.init();
        messageEditLayout = findViewById(R.id.message_edit_layout);
        messageEditText = messageEditLayout.findViewById(LiveMessageEditLayout.EDIT_TEXT_ID);

        rtcStatsView = findViewById(R.id.single_host_rtc_stats);
        rtcStatsView.setCloseListener(view -> rtcStatsView.setVisibility(View.GONE));

        // In case that the UI is not relocated because
        // the permission request dialog consumes the chance
        onGlobalLayoutCompleted();
    }

    @Override
    protected void onGlobalLayoutCompleted() {
        View topLayout = findViewById(R.id.single_live_top_participant_layout);
        if (topLayout != null && !mTopLayoutCalculated) {
            RelativeLayout.LayoutParams params =
                    (RelativeLayout.LayoutParams) topLayout.getLayoutParams();
            params.topMargin += systemBarHeight;
            topLayout.setLayoutParams(params);
            mTopLayoutCalculated = true;
        }
    }

    @Override
    public void onClick(View view) {
        switch (view.getId()) {
            case R.id.live_bottom_btn_close:
                curDialog = showDialog(R.string.end_live_streaming_title_owner,
                        R.string.end_live_streaming_message_owner, this);
                break;
            case R.id.live_bottom_btn_more:
                LiveRoomToolActionSheet toolSheet = (LiveRoomToolActionSheet) showActionSheetDialog(
                        ACTION_SHEET_TOOL, tabIdToLiveType(tabId), isOwner, true, this);
                toolSheet.setEnableInEarMonitoring(inEarMonitorEnabled);
                break;
            case R.id.live_bottom_btn_fun1:
                if (isHost || isOwner) {
                    showActionSheetDialog(ACTION_SHEET_BG_MUSIC, tabIdToLiveType(tabId), true, true, this);
                } else {
                    showActionSheetDialog(ACTION_SHEET_GIFT, tabIdToLiveType(tabId), false, true, this);
                }
                break;
            case R.id.live_bottom_btn_fun2:
                // this button is hidden when
                // current user is not host.
                if (isHost || isOwner) {
                    showActionSheetDialog(ACTION_SHEET_BEAUTY, tabIdToLiveType(tabId), true, true, this);
                }
                break;
            case R.id.dialog_positive_button:
                closeDialog();
                finish();
                break;
        }
    }

    private void becomesOwner(boolean audioMuted, boolean videoMuted) {
        if (!videoMuted) startCameraCapture();
        bottomButtons.setRole(LiveBottomButtonLayout.ROLE_OWNER);
        bottomButtons.setBeautyEnabled(config().isBeautyEnabled());
        rtcEngine().setClientRole(Constants.CLIENT_ROLE_BROADCASTER);
        config().setAudioMuted(audioMuted);
        config().setVideoMuted(videoMuted);
        initLocalPreview();
    }

    private void initLocalPreview() {
        CameraTextureView textureView = new CameraTextureView(this);
        mVideoLayout.addView(textureView);
    }
}

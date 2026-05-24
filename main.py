import os
import re
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.scrollview import ScrollView
from kivy.core.clipboard import Clipboard
from kivy.utils import platform
import subprocess


class SessionIDExtractorApp(App):
    def build(self):
        self.title = '抖音SessionID提取器'
        
        layout = BoxLayout(orientation='vertical', padding=10, spacing=10)
        
        title_label = Label(
            text='抖音SessionID提取器',
            size_hint=(1, 0.1),
            font_size='20sp',
            bold=True
        )
        layout.add_widget(title_label)
        
        info_label = Label(
            text='需要ROOT权限才能访问应用数据',
            size_hint=(1, 0.08),
            font_size='14sp',
            color=(1, 0.5, 0, 1)
        )
        layout.add_widget(info_label)
        
        extract_btn = Button(
            text='提取SessionID',
            size_hint=(1, 0.12),
            font_size='18sp',
            background_color=(0.2, 0.6, 1, 1)
        )
        extract_btn.bind(on_press=self.extract_sessionid)
        layout.add_widget(extract_btn)
        
        result_label = Label(
            text='结果:',
            size_hint=(1, 0.08),
            font_size='16sp',
            halign='left',
            valign='middle'
        )
        result_label.bind(size=result_label.setter('text_size'))
        layout.add_widget(result_label)
        
        scroll_view = ScrollView(size_hint=(1, 0.5))
        self.result_text = TextInput(
            text='',
            readonly=True,
            multiline=True,
            font_size='14sp',
            background_color=(0.95, 0.95, 0.95, 1),
            foreground_color=(0, 0, 0, 1)
        )
        scroll_view.add_widget(self.result_text)
        layout.add_widget(scroll_view)
        
        copy_btn = Button(
            text='复制到剪贴板',
            size_hint=(1, 0.12),
            font_size='18sp',
            background_color=(0.2, 0.8, 0.2, 1)
        )
        copy_btn.bind(on_press=self.copy_to_clipboard)
        layout.add_widget(copy_btn)
        
        return layout
    
    def extract_sessionid(self, instance):
        self.result_text.text = '正在提取...\n'
        
        target_path = '/data/data/com.ss.android.ugc.aweme.mobile/files/keva/repo/aweme_feed_cookie_store/'
        
        try:
            if platform == 'android':
                result = self.extract_from_android(target_path)
            else:
                result = self.extract_from_desktop(target_path)
            
            if result:
                self.result_text.text = f'提取成功!\n\n{result}'
            else:
                self.result_text.text = '未找到sessionid_ss参数\n请确保:\n1. 设备已ROOT\n2. 已安装抖音应用\n3. 已登录抖音账号'
                
        except Exception as e:
            self.result_text.text = f'错误: {str(e)}\n\n请确保设备已获取ROOT权限'
    
    def extract_from_android(self, target_path):
        from android.permissions import request_permissions, Permission
        from jnius import autoclass
        
        request_permissions([Permission.READ_EXTERNAL_STORAGE, Permission.WRITE_EXTERNAL_STORAGE])
        
        sessionid_list = []
        
        try:
            result = subprocess.run(
                ['su', '-c', f'ls {target_path}'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode != 0:
                return None
            
            files = result.stdout.strip().split('\n')
            
            for filename in files:
                if not filename:
                    continue
                    
                file_path = os.path.join(target_path, filename)
                
                read_result = subprocess.run(
                    ['su', '-c', f'cat {file_path}'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if read_result.returncode == 0:
                    content = read_result.stdout
                    matches = re.findall(r'sessionid_ss=([^;\s&]+)', content)
                    
                    for match in matches:
                        if match not in sessionid_list:
                            sessionid_list.append(match)
            
            if sessionid_list:
                result_text = f'找到 {len(sessionid_list)} 个SessionID:\n\n'
                for idx, sid in enumerate(sessionid_list, 1):
                    result_text += f'{idx}. sessionid_ss={sid}\n\n'
                return result_text
            
        except subprocess.TimeoutExpired:
            return '执行超时，请检查ROOT权限'
        except Exception as e:
            return f'读取失败: {str(e)}'
        
        return None
    
    def extract_from_desktop(self, target_path):
        self.result_text.text += '桌面模式: 模拟数据\n\n'
        return 'sessionid_ss=1234567890abcdef1234567890abcdef\n\n(这是测试数据，请在Android设备上运行以获取真实数据)'
    
    def copy_to_clipboard(self, instance):
        text = self.result_text.text
        if text and text != '正在提取...\n':
            Clipboard.copy(text)
            self.result_text.text = text + '\n\n已复制到剪贴板!'


if __name__ == '__main__':
    SessionIDExtractorApp().run()

from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.scrollview import ScrollView
from kivy.core.clipboard import Clipboard
import subprocess
import re


class SessionIDExtractorApp(App):
    def build(self):
        self.title = 'SessionID Extractor'
        
        layout = BoxLayout(orientation='vertical', padding=10, spacing=10)
        
        title_label = Label(
            text='Douyin SessionID Extractor',
            size_hint=(1, 0.1),
            font_size='20sp'
        )
        layout.add_widget(title_label)
        
        info_label = Label(
            text='Requires ROOT access',
            size_hint=(1, 0.08),
            font_size='14sp'
        )
        layout.add_widget(info_label)
        
        extract_btn = Button(
            text='Extract SessionID',
            size_hint=(1, 0.12),
            font_size='18sp'
        )
        extract_btn.bind(on_press=self.extract_sessionid)
        layout.add_widget(extract_btn)
        
        result_label = Label(
            text='Result:',
            size_hint=(1, 0.08),
            font_size='16sp'
        )
        layout.add_widget(result_label)
        
        scroll_view = ScrollView(size_hint=(1, 0.5))
        self.result_text = TextInput(
            text='',
            readonly=True,
            multiline=True,
            font_size='14sp'
        )
        scroll_view.add_widget(self.result_text)
        layout.add_widget(scroll_view)
        
        copy_btn = Button(
            text='Copy to Clipboard',
            size_hint=(1, 0.12),
            font_size='18sp'
        )
        copy_btn.bind(on_press=self.copy_to_clipboard)
        layout.add_widget(copy_btn)
        
        return layout
    
    def extract_sessionid(self, instance):
        self.result_text.text = 'Extracting...\n'
        
        target_path = '/data/data/com.ss.android.ugc.aweme.mobile/files/keva/repo/aweme_feed_cookie_store/'
        
        try:
            result = subprocess.run(
                ['su', '-c', f'ls {target_path}'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode != 0:
                self.result_text.text = 'Failed to access directory\nPlease ensure:\n1. Device is rooted\n2. Douyin app is installed\n3. ROOT permission granted'
                return
            
            files = result.stdout.strip().split('\n')
            sessionid_list = []
            
            for filename in files:
                if not filename:
                    continue
                    
                file_path = f'{target_path}{filename}'
                
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
                result_text = f'Found {len(sessionid_list)} SessionID(s):\n\n'
                for idx, sid in enumerate(sessionid_list, 1):
                    result_text += f'{idx}. sessionid_ss={sid}\n\n'
                self.result_text.text = result_text
            else:
                self.result_text.text = 'No sessionid_ss found\nPlease ensure you are logged in to Douyin'
                
        except subprocess.TimeoutExpired:
            self.result_text.text = 'Timeout error\nPlease check ROOT permission'
        except Exception as e:
            self.result_text.text = f'Error: {str(e)}'
    
    def copy_to_clipboard(self, instance):
        text = self.result_text.text
        if text and text != 'Extracting...\n':
            Clipboard.copy(text)
            self.result_text.text = text + '\n\nCopied to clipboard!'


if __name__ == '__main__':
    SessionIDExtractorApp().run()
